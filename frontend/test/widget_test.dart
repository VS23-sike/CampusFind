import 'package:flutter_test/flutter_test.dart';
import 'package:campusfind/main.dart';

void main() {
  testWidgets('CampusFind app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusFindApp());

    expect(find.byType(CampusFindApp), findsOneWidget);
  });
}
