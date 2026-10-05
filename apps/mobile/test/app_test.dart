import 'package:cocenglish/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('welcome exposes both reference entry actions', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    expect(find.text('Learn for free. Forever.'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('I ALREADY HAVE AN ACCOUNT'), findsOneWidget);
  });
}
