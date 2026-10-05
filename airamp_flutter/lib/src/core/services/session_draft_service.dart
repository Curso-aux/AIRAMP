import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service to persist and restore form and input field drafts
/// across browser refreshes (Web) and navigation back-stack/undo transitions (Mobile/App).
class SessionDraftService {
  static final SessionDraftService _instance = SessionDraftService._internal();
  factory SessionDraftService() => _instance;
  static SessionDraftService get instance => _instance;

  SessionDraftService._internal();

  SharedPreferences? _prefs;
  final Map<String, String> _memoryCache = {};
  bool _isInitialized = false;

  /// Default time-to-live for unsubmitted drafts (24 hours).
  static const Duration defaultTtl = Duration(hours: 24);

  /// Initializes SharedPreferences and pre-populates in-memory cache for synchronous reads.
  Future<void> init({SharedPreferences? customPrefs}) async {
    try {
      _prefs = customPrefs ?? await SharedPreferences.getInstance();
      _memoryCache.clear();

      final now = DateTime.now().millisecondsSinceEpoch;
      final keys = _prefs?.getKeys() ?? <String>{};

      for (final key in keys) {
        if (key.startsWith('draft:')) {
          final ts = _prefs?.getInt('ts:$key');
          if (ts != null && now - ts > defaultTtl.inMilliseconds) {
            // Expired draft - prune
            await _prefs?.remove(key);
            await _prefs?.remove('ts:$key');
          } else {
            final val = _prefs?.getString(key);
            if (val != null && val.isNotEmpty) {
              _memoryCache[key] = val;
            }
          }
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[SessionDraftService] Initialization error: $e');
    }
  }

  bool get isInitialized => _isInitialized;

  /// Generates namespaced storage key.
  String _buildKey(String formId, String fieldKey, String? userId) {
    final effectiveUser = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : 'session';
    return 'draft:$effectiveUser:$formId:$fieldKey';
  }

  /// Synchronously retrieves a drafted value from memory cache or storage.
  String? getField(String formId, String fieldKey, {String? userId}) {
    final key = _buildKey(formId, fieldKey, userId);
    return _memoryCache[key] ?? _prefs?.getString(key);
  }

  /// Saves a field draft in memory immediately and asynchronously persists to disk/session storage.
  Future<void> saveField(String formId, String fieldKey, String value, {String? userId}) async {
    final key = _buildKey(formId, fieldKey, userId);
    if (value.trim().isEmpty) {
      _memoryCache.remove(key);
      await _prefs?.remove(key);
      await _prefs?.remove('ts:$key');
    } else {
      _memoryCache[key] = value;
      await _prefs?.setString(key, value);
      await _prefs?.setInt('ts:$key', DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Removes all drafted fields associated with a specific form or screen ID.
  Future<void> clearForm(String formId, {String? userId}) async {
    final effectiveUser = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : 'session';
    final prefix = 'draft:$effectiveUser:$formId:';

    _memoryCache.removeWhere((k, _) => k.startsWith(prefix));

    final allKeys = _prefs?.getKeys().where((k) => k.startsWith(prefix)).toList() ?? [];
    for (final k in allKeys) {
      await _prefs?.remove(k);
      await _prefs?.remove('ts:$k');
    }
  }

  /// Removes a single drafted field.
  Future<void> clearField(String formId, String fieldKey, {String? userId}) async {
    final key = _buildKey(formId, fieldKey, userId);
    _memoryCache.remove(key);
    await _prefs?.remove(key);
    await _prefs?.remove('ts:$key');
  }

  /// Checks if any draft content exists for the given form.
  bool hasDraft(String formId, {String? userId}) {
    final effectiveUser = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : 'session';
    final prefix = 'draft:$effectiveUser:$formId:';
    return _memoryCache.keys.any((k) => k.startsWith(prefix));
  }

  /// Retrieves all field drafts belonging to the given form as a map.
  Map<String, String> getFormDraft(String formId, {String? userId}) {
    final effectiveUser = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : 'session';
    final prefix = 'draft:$effectiveUser:$formId:';
    final Map<String, String> result = {};

    for (final entry in _memoryCache.entries) {
      if (entry.key.startsWith(prefix)) {
        final fieldKey = entry.key.substring(prefix.length);
        result[fieldKey] = entry.value;
      }
    }
    return result;
  }
}

/// Disposer utility to unbind multiple controller draft listeners cleanly upon widget disposal.
class SessionDraftDisposer {
  final List<VoidCallback> _unbinders = [];

  void add(VoidCallback unbinder) => _unbinders.add(unbinder);

  void dispose() {
    for (final u in _unbinders) {
      try {
        u();
      } catch (_) {}
    }
    _unbinders.clear();
  }
}

/// Extension on [TextEditingController] for 1-line draft binding and auto-restoration.
extension SessionDraftExtension on TextEditingController {
  /// Binds this controller to [SessionDraftService]:
  /// 1. Immediately restores any previously typed draft if the controller text is empty.
  /// 2. Attaches a debounced listener to persist updates whenever the user types.
  /// 3. Returns a [VoidCallback] to cancel debouncing and detach the listener upon disposal.
  VoidCallback bindSessionDraft({
    required String formId,
    required String fieldKey,
    String? userId,
    Duration debounceDuration = const Duration(milliseconds: 250),
    VoidCallback? onDraftRestored,
  }) {
    // 1. Initial restoration
    final existingDraft = SessionDraftService.instance.getField(formId, fieldKey, userId: userId);
    if (existingDraft != null && existingDraft.isNotEmpty && text.isEmpty) {
      text = existingDraft;
      selection = TextSelection.collapsed(offset: existingDraft.length);
      onDraftRestored?.call();
    }

    // 2. Debounced auto-save listener
    Timer? debounceTimer;
    void listener() {
      debounceTimer?.cancel();
      debounceTimer = Timer(debounceDuration, () {
        SessionDraftService.instance.saveField(formId, fieldKey, text, userId: userId);
      });
    }

    addListener(listener);

    // 3. Return unbind callback
    return () {
      debounceTimer?.cancel();
      removeListener(listener);
    };
  }
}
