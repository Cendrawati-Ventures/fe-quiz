import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_exam_system/shared/components/app_button.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('AppButton', () {
    testWidgets('menampilkan label dan memanggil onPressed', (tester) async {
      var tapped = 0;

      await tester.pumpWidget(
        wrap(
          AppButton(
            label: 'Simpan',
            onPressed: () => tapped += 1,
          ),
        ),
      );

      expect(find.text('Simpan'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('mode loading menonaktifkan tombol', (tester) async {
      var tapped = 0;

      await tester.pumpWidget(
        wrap(
          AppButton(
            label: 'Kirim',
            onPressed: () => tapped += 1,
            loading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(tapped, 0);
    });
  });
}
