import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/presentation/web/admin_web_login_screen.dart';

void main() {
  testWidgets('Web Portal Login Screen renders unified Single Sign-In UI with no role tabs', (tester) async {
    // 1. Default Unified Single Sign-In View
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminWebLoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AIRAMP Portal'), findsOneWidget);
    expect(find.text('SINGLE SIGN-IN · INSTITUTIONAL ACCESS'), findsOneWidget);
    expect(find.text('Student ID, Email, or Username'), findsOneWidget);
    expect(find.text('Sign In to Portal'), findsOneWidget);
    expect(find.text('Unified Authentication · Automatic Role Routing'), findsOneWidget);

    // Verify role-specific headers and segmented tabs are NOT present
    expect(find.text('Teacher Portal'), findsNothing);
    expect(find.text('Student Portal'), findsNothing);
    expect(find.text('Admin Web Console'), findsNothing);
    expect(find.text('FACULTY ACCESS'), findsNothing);
    expect(find.text('LEARNER ACCESS'), findsNothing);
    expect(find.text('INSTITUTION ACCESS'), findsNothing);

    // 2. Initial role parameter (e.g. from legacy links) must still render unified Single Sign-In
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminWebLoginScreen(initialRole: 'teacher'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AIRAMP Portal'), findsOneWidget);
    expect(find.text('SINGLE SIGN-IN · INSTITUTIONAL ACCESS'), findsOneWidget);
    expect(find.text('Teacher Portal'), findsNothing);
    expect(find.text('FACULTY ACCESS'), findsNothing);
  });
}
