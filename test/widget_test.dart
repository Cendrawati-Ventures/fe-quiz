import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_exam_system/shared/components/connection_chip.dart';

void main() {
  testWidgets('ConnectionChip menampilkan status online + label sync',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectionChip(
            isOnline: true,
            syncStatus: 'synced',
          ),
        ),
      ),
    );

    expect(find.text('Terhubung | Tersimpan'), findsOneWidget);
  });
}
