import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../data/semester_record_archiving_service.dart';
import '../../data/semester_selective_purge_service.dart';
import '../../domain/semester_archive_models.dart';

/// Immutable state modeling the semester archive generation and selective purge lifecycle.
class SemesterRenewalState {
  final bool isArchiveGenerating;
  final bool isArchiveVerified;
  final ArchiveVerificationResult? verificationResult;
  final bool isPurging;
  final PurgeSummary? purgeSummary;
  final String? errorMessage;
  final List<StudentArchiveRecord>? records;

  const SemesterRenewalState({
    this.isArchiveGenerating = false,
    this.isArchiveVerified = false,
    this.verificationResult,
    this.isPurging = false,
    this.purgeSummary,
    this.errorMessage,
    this.records,
  });

  /// STRICT GUARD: Reset is unlocked ONLY when archive generation is verified
  /// and the verification result explicitly confirms validity.
  bool get isResetUnlocked =>
      isArchiveVerified && (verificationResult?.isValid == true);

  SemesterRenewalState copyWith({
    bool? isArchiveGenerating,
    bool? isArchiveVerified,
    ArchiveVerificationResult? verificationResult,
    bool? isPurging,
    PurgeSummary? purgeSummary,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<StudentArchiveRecord>? records,
  }) {
    return SemesterRenewalState(
      isArchiveGenerating: isArchiveGenerating ?? this.isArchiveGenerating,
      isArchiveVerified: isArchiveVerified ?? this.isArchiveVerified,
      verificationResult: verificationResult ?? this.verificationResult,
      isPurging: isPurging ?? this.isPurging,
      purgeSummary: purgeSummary ?? this.purgeSummary,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      records: records ?? this.records,
    );
  }
}

/// Notifier controlling the institutional Excel/ZIP archiving, verification,
/// file download dispatch, and guarded selective academic database purge.
class SemesterRenewalNotifier extends Notifier<SemesterRenewalState> {
  final ISemesterRecordArchivingService? _customArchivingService;
  final ISemesterSelectivePurgeService? _customPurgeService;
  SemesterRenewalState? _fallbackState;

  SemesterRenewalNotifier({
    ISemesterRecordArchivingService? archivingService,
    ISemesterSelectivePurgeService? purgeService,
  })  : _customArchivingService = archivingService,
        _customPurgeService = purgeService;

  ISemesterRecordArchivingService get archivingService =>
      _customArchivingService ?? ref.read(semesterArchivingServiceProvider);

  ISemesterSelectivePurgeService get purgeService =>
      _customPurgeService ?? ref.read(semesterPurgeServiceProvider);

  @override
  SemesterRenewalState build() {
    return const SemesterRenewalState();
  }

  @override
  SemesterRenewalState get state {
    try {
      return super.state;
    } catch (_) {
      return _fallbackState ??= const SemesterRenewalState();
    }
  }

  @override
  set state(SemesterRenewalState value) {
    try {
      super.state = value;
    } catch (_) {
      _fallbackState = value;
    }
  }

  /// Primary method: Queries all student records, compiles them into structured
  /// Excel (.xlsx) workbooks bundled in a .zip archive, validates byte integrity,
  /// and dispatches browser download if verified.
  Future<ArchiveVerificationResult?> generateAndDownloadExcelZipArchive({
    String? academicYear,
    String? semester,
  }) async {
    state = state.copyWith(isArchiveGenerating: true, clearErrorMessage: true);

    try {
      final records = await archivingService.fetchAllStudentRecords();
      final ay = academicYear ?? 'AY2025-2026';
      final sem = semester ?? '1stSemester';
      final zipBytes = await archivingService.generateExcelZipArchive(
        records: records,
        academicYear: ay,
        semester: sem,
      );
      final result = archivingService.verifyZipArchive(zipBytes, records.length);

      if (result.isValid) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final cleanAy = ay.replaceAll(' ', '_');
          final cleanSem = sem.replaceAll(' ', '_');
          downloadBinaryFileWeb(
            zipBytes,
            'CampusRecords_${cleanAy}_${cleanSem}_$timestamp.zip',
            'application/zip',
          );
        } catch (downloadErr) {
          debugPrint('[SemesterRenewalNotifier] Download dispatch note: $downloadErr');
        }

        state = state.copyWith(
          isArchiveGenerating: false,
          isArchiveVerified: true,
          verificationResult: result,
          records: records,
          clearErrorMessage: true,
        );
      } else {
        state = state.copyWith(
          isArchiveGenerating: false,
          isArchiveVerified: false,
          verificationResult: result,
          errorMessage: result.errorMessage ?? 'Archive integrity verification failed.',
        );
      }
      return result;
    } catch (e, st) {
      debugPrint('[SemesterRenewalNotifier] generateAndDownloadExcelZipArchive error: $e\n$st');
      state = state.copyWith(
        isArchiveGenerating: false,
        isArchiveVerified: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Alias for backward compatibility with existing tests and calls.
  Future<ArchiveVerificationResult?> generateAndDownloadArchive({
    String? academicYear,
    String? semester,
  }) async {
    return generateAndDownloadExcelZipArchive(
      academicYear: academicYear,
      semester: semester,
    );
  }

  /// Executes the selective academic database purge guarded strictly by archive verification.
  /// Throws a [StateError] if triggered before archive verification has succeeded.
  Future<PurgeSummary> executeReset({
    required String adminId,
    required String schoolId,
    String? previousSemester,
    String? newSemester,
  }) async {
    if (!state.isResetUnlocked) {
      throw StateError(
        'Cannot execute semester reset: Archive generation and verification is required.',
      );
    }

    state = state.copyWith(isPurging: true, clearErrorMessage: true);

    try {
      final summary = await purgeService.executeSelectivePurge(
        adminId: adminId,
        schoolId: schoolId,
        previousSemester: previousSemester,
        newSemester: newSemester,
      );

      state = state.copyWith(
        isPurging: false,
        purgeSummary: summary,
        clearErrorMessage: true,
      );
      return summary;
    } catch (e) {
      state = state.copyWith(
        isPurging: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Reset notifier state back to initial state (e.g. after modal dismissal or cycle completion)
  void resetState() {
    state = const SemesterRenewalState();
  }
}

/// Provider for the archiving service
final semesterArchivingServiceProvider =
    Provider<ISemesterRecordArchivingService>((ref) {
  return SemesterRecordArchivingService();
});

/// Provider for the selective purge service
final semesterPurgeServiceProvider =
    Provider<ISemesterSelectivePurgeService>((ref) {
  return SemesterSelectivePurgeService();
});

/// NotifierProvider exposing the semester renewal controller state and actions
final semesterRenewalControllerProvider =
    NotifierProvider<SemesterRenewalNotifier, SemesterRenewalState>(() {
  return SemesterRenewalNotifier();
});
