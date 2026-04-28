import 'package:flutter_test/flutter_test.dart';
import 'package:online_exam_system/core/utils/debounce.dart';

void main() {
  group('Debouncer', () {
    test('menjalankan aksi terakhir saja', () async {
      final debouncer = Debouncer(const Duration(milliseconds: 30));
      var latestValue = 0;

      debouncer.run(() => latestValue = 1);
      debouncer.run(() => latestValue = 2);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(latestValue, 2);
      debouncer.dispose();
    });

    test('membatalkan aksi saat dispose', () async {
      final debouncer = Debouncer(const Duration(milliseconds: 30));
      var runCount = 0;

      debouncer.run(() => runCount += 1);
      debouncer.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(runCount, 0);
    });
  });
}
