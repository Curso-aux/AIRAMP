import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airamp_flutter/src/core/services/session_draft_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionDraftService.instance.init();
  });

  group('SessionDraftService Tests', () {
    test('saveField and getField stores and retrieves values', () async {
      await SessionDraftService.instance.saveField('quiz_form', 'title', 'Midterm Examination');
      expect(SessionDraftService.instance.getField('quiz_form', 'title'), 'Midterm Examination');

      // Check empty value cleans up field
      await SessionDraftService.instance.saveField('quiz_form', 'title', '');
      expect(SessionDraftService.instance.getField('quiz_form', 'title'), isNull);
    });

    test('clearForm deletes all fields for the form', () async {
      await SessionDraftService.instance.saveField('announcement', 'title', 'Exam Schedule');
      await SessionDraftService.instance.saveField('announcement', 'body', 'Please arrive at 8am.');
      await SessionDraftService.instance.saveField('other_form', 'title', 'Keep Me');

      expect(SessionDraftService.instance.hasDraft('announcement'), isTrue);
      expect(SessionDraftService.instance.hasDraft('other_form'), isTrue);

      await SessionDraftService.instance.clearForm('announcement');

      expect(SessionDraftService.instance.hasDraft('announcement'), isFalse);
      expect(SessionDraftService.instance.getField('announcement', 'title'), isNull);
      expect(SessionDraftService.instance.getField('announcement', 'body'), isNull);
      expect(SessionDraftService.instance.getField('other_form', 'title'), 'Keep Me');
    });

    test('getFormDraft returns full map of saved fields', () async {
      await SessionDraftService.instance.saveField('quiz_1', 'q0', 'What is AI?');
      await SessionDraftService.instance.saveField('quiz_1', 'optA', 'Artificial Intelligence');

      final draft = SessionDraftService.instance.getFormDraft('quiz_1');
      expect(draft['q0'], 'What is AI?');
      expect(draft['optA'], 'Artificial Intelligence');
    });

    test('TextEditingController.bindSessionDraft restores existing draft immediately', () {
      SessionDraftService.instance.saveField('login', 'username', 'student_maria');

      final controller = TextEditingController();
      expect(controller.text, '');

      final unbind = controller.bindSessionDraft(formId: 'login', fieldKey: 'username');
      expect(controller.text, 'student_maria');

      unbind();
      controller.dispose();
    });

    test('TextEditingController.bindSessionDraft debounces and auto-saves changes', () async {
      final controller = TextEditingController();
      final unbind = controller.bindSessionDraft(
        formId: 'essay',
        fieldKey: 'body',
        debounceDuration: const Duration(milliseconds: 50),
      );

      controller.text = 'My initial thoughts...';
      // Wait for debounce timer
      await Future.delayed(const Duration(milliseconds: 100));

      expect(SessionDraftService.instance.getField('essay', 'body'), 'My initial thoughts...');

      unbind();
      controller.dispose();
    });
  });
}
