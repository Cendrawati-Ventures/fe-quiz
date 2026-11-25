import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_exam_system/shared/components/option_item.dart';

void main() {
  testWidgets('OptionItem menampilkan gambar jawaban dan dapat dipilih',
      (tester) async {
    var tapped = false;
    const tinyPng =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z2S0AAAAASUVORK5CYII=';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionItem(
            option: 'A. Anak memakai topi',
            imageData: tinyPng,
            selected: false,
            multiSelect: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('A. Anak memakai topi'), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });
}
