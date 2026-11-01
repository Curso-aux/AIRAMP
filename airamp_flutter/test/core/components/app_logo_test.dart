import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/app_logo.dart';

void main() {
  testWidgets('AppLogo renders properly and finds asset in dark mode', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLogo(isDark: true),
          ),
        ),
      ),
    );

    // Verify Brand Text is present
    expect(find.text('AIRA'), findsOneWidget);
    expect(find.text('Academic Integrated Review & Assessment'), findsOneWidget);
    expect(find.text('Train Smart. Get Certified!'), findsOneWidget);

    // Verify Image.asset is present with assets/images/aira_logo.png
    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<Image>(imageFinder);
    expect((imageWidget.image as AssetImage).assetName, 'assets/images/aira_logo.png');
  });

  testWidgets('AppLogo renders in light mode with black logo asset', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLogo(isDark: false),
          ),
        ),
      ),
    );

    expect(find.text('AIRA'), findsOneWidget);
    expect(find.text('Academic Integrated Review & Assessment'), findsOneWidget);
    expect(find.text('Train Smart. Get Certified!'), findsOneWidget);

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<Image>(imageFinder);
    expect((imageWidget.image as AssetImage).assetName, 'assets/images/aira_logo_dark.png');
  });

  test('aira_logo.png and aira_logo_dark.png assets can be loaded from rootBundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dataPrimary = await rootBundle.load('assets/images/aira_logo.png');
    expect(dataPrimary.lengthInBytes, greaterThan(0));

    final dataDark = await rootBundle.load('assets/images/aira_logo_dark.png');
    expect(dataDark.lengthInBytes, greaterThan(0));
  });

  testWidgets('AppLogo with showText false renders only emblem', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLogo(showText: false),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('AIRA'), findsNothing);
  });

  testWidgets('AppLogo.mark renders compact emblem without background box', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppLogo.mark(size: 38, isDark: true),
              AppLogo.mark(size: 38, isDark: false),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsNWidgets(2));
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('AIRA'), findsNothing);
  });
}
