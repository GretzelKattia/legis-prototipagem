import 'package:flutter_test/flutter_test.dart';

import 'package:legis_frontend/main.dart';

void main() {
  testWidgets('exibe a tela inicial do LEGIS', (tester) async {
    await tester.pumpWidget(const LegisApp());
    expect(find.text('LEGIS'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });
}
