import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/app_logo.dart';

void main() {
  testWidgets('AppLogo renders properly and finds asset', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLogo(),
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

  test('aira_logo.png asset can be loaded from rootBundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load('assets/images/aira_logo.png');
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('AppLogo with showText false renders only image container', (WidgetTester tester) async {
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
}
