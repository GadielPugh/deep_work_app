import 'package:flutter_test/flutter_test.dart';

import 'package:deep_work/main.dart';

void main() {
  testWidgets('app renders the main tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Sessions'), findsWidgets);
    expect(find.text('Insights'), findsWidgets);
  });
}
