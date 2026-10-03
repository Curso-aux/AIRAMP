import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/presentation/web/admin_web_login_screen.dart';

void main() {
  testWidgets('Web Portal Login Screen renders role-specific UI based on initialRole', (tester) async {
    // 1. Student Portal View
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminWebLoginScreen(initialRole: 'student'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Student Portal'), findsOneWidget);
    expect(find.text('LEARNER ACCESS'), findsOneWidget);
    expect(find.text('Student ID or Username'), findsOneWidget);
    expect(find.text('Sign In to Student Portal'), findsOneWidget);

    // 2. Teacher Portal View
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminWebLoginScreen(initialRole: 'teacher'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teacher Portal'), findsOneWidget);
    expect(find.text('FACULTY ACCESS'), findsOneWidget);
    expect(find.text('Faculty Email or Username'), findsOneWidget);
    expect(find.text('Sign In to Teacher Portal'), findsOneWidget);

    // 3. Admin Console View
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminWebLoginScreen(initialRole: 'admin'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Web Console'), findsOneWidget);
    expect(find.text('INSTITUTION ACCESS'), findsOneWidget);
    expect(find.text('Administrator Email or Username'), findsOneWidget);
    expect(find.text('Sign In to Admin Console'), findsOneWidget);
  });
}
