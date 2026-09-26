import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../domain/module_scanner_service.dart';

final moduleScannerServiceProvider = Provider<ModuleScannerService>((ref) {
  return ModuleScannerService();
});

/// State for a module's review deck
class ModuleDeckState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? moduleData;
  final List<Map<String, dynamic>> cards;
  final int masteredCount;
  final int weakCount;

  const ModuleDeckState({
    this.isLoading = true,
    this.errorMessage,
    this.moduleData,
    this.cards = const [],
    this.masteredCount = 0,
    this.weakCount = 0,
  });

  ModuleDeckState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? moduleData,
    List<Map<String, dynamic>>? cards,
    int? masteredCount,
    int? weakCount,
  }) {
    return ModuleDeckState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      moduleData: moduleData ?? this.moduleData,
      cards: cards ?? this.cards,
      masteredCount: masteredCount ?? this.masteredCount,
      weakCount: weakCount ?? this.weakCount,
    );
  }
}

/// Provider managing the active module review session
final moduleReviewProvider =
    NotifierProvider<ModuleReviewNotifier, ModuleDeckState>(() {
  return ModuleReviewNotifier();
});

class ModuleReviewNotifier extends Notifier<ModuleDeckState> {
  int? _loId;

  @override
  ModuleDeckState build() {
    return const ModuleDeckState(isLoading: true);
  }

  Future<void> loadDeck(int loId, {bool forceRefresh = false}) async {
    _loId = loId;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final dbHelper = DatabaseHelper();
      final moduleData = await dbHelper.getModuleDataForReview(loId);
      final scanner = ref.read(moduleScannerServiceProvider);
      final cards = await scanner.scanAndGenerateCards(loId: loId, forceRefresh: forceRefresh);

      int mastered = 0;
      int weak = 0;
      for (final c in cards) {
        if (c['is_mastered'] == 1 || c['is_mastered'] == true) {
          mastered++;
        } else {
          weak++;
        }
      }

      state = state.copyWith(
        isLoading: false,
        moduleData: moduleData,
        cards: cards,
        masteredCount: mastered,
        weakCount: weak,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to scan module: $e',
      );
    }
  }

  Future<void> refreshDeck() async {
    if (_loId != null) {
      await loadDeck(_loId!, forceRefresh: true);
    }
  }

  Future<void> updateCardMastery(int cardId, bool isMastered) async {
    await DatabaseHelper().updateFlashcardMastery(cardId, isMastered);

    // Update in-memory state
    final updated = state.cards.map((c) {
      if (c['id'] == cardId) {
        return {
          ...c,
          'is_mastered': isMastered ? 1 : 0,
          'review_count': ((c['review_count'] as int?) ?? 0) + 1,
        };
      }
      return c;
    }).toList();

    int mastered = 0;
    int weak = 0;
    for (final c in updated) {
      if (c['is_mastered'] == 1 || c['is_mastered'] == true) {
        mastered++;
      } else {
        weak++;
      }
    }

    state = state.copyWith(
      cards: updated,
      masteredCount: mastered,
      weakCount: weak,
    );
  }

  Future<void> resetMastery() async {
    if (_loId != null) {
      await DatabaseHelper().resetModuleFlashcardMastery(_loId!);
      final updated = state.cards.map((c) => {...c, 'is_mastered': 0}).toList();
      state = state.copyWith(
        cards: updated,
        masteredCount: 0,
        weakCount: updated.length,
      );
    }
  }
}
