import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_exam_system/shared/components/timer_widget.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('TimerWidget', () {
    testWidgets('format waktu jam:menit:detik', (tester) async {
      await tester.pumpWidget(
        wrap(const TimerWidget(remainingSeconds: 3661)),
      );

      expect(find.text('01:01:01'), findsOneWidget);
    });

    testWidgets('format nol untuk waktu singkat', (tester) async {
      await tester.pumpWidget(
        wrap(const TimerWidget(remainingSeconds: 9)),
      );

      expect(find.text('00:00:09'), findsOneWidget);
    });
  });
}
