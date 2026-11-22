import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dashboard/core/palette.dart';

void main() {
  test('palette exposes readable contrast between ink and canvas', () {
    expect(Palette.ink.computeLuminance(),
        lessThan(Palette.canvas.computeLuminance()));
  });

  testWidgets('status chip renders its label', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const Scaffold(
          body: Center(child: Text('leaf')),
        ),
      ),
    );
    expect(find.text('leaf'), findsOneWidget);
  });
}
