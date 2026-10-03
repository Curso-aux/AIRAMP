import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/presentation/web/admin_web_login_screen.dart';

void main() {
  testWidgets('Web Portal Login Screen renders universal UI for students, faculty & admins', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminWebLoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('AIRA Web Portal'), findsOneWidget);
    expect(find.text('Unified Learning & Management Portal'), findsOneWidget);

    // Verify inclusive welcome notice
    expect(find.textContaining('Students, Faculty, and Administrators'), findsOneWidget);

    // Verify field labels and hints
    expect(find.text('Student ID, Email or Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    // Verify button text
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign In to Web Admin'), findsNothing);
  });
}
