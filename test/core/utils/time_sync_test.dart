import 'package:flutter_test/flutter_test.dart';
import 'package:online_exam_system/core/utils/time_sync.dart';

void main() {
  group('TimeSync', () {
    test('sinkron offset dari UTC server', () {
      final sync = TimeSync();
      final localUtc = DateTime.now().toUtc();
      final serverUtc = localUtc.add(const Duration(seconds: 5));

      sync.syncFromServerUtc(serverUtc);

      expect(sync.serverOffsetMs, inInclusiveRange(4500, 5500));
    });

    test('sinkron offset dari epoch milliseconds', () {
      final sync = TimeSync();
      final serverEpochMs = DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 3))
          .millisecondsSinceEpoch;

      sync.syncFromServerEpochMs(serverEpochMs);

      expect(sync.serverOffsetMs, inInclusiveRange(2500, 3500));
    });

    test('nowServerUtc mengikuti offset server', () {
      final sync = TimeSync();
      sync.syncFromServerUtc(DateTime.now().toUtc().add(const Duration(seconds: 2)));

      final driftMs =
          sync.nowServerUtc().difference(DateTime.now().toUtc()).inMilliseconds;
      expect(driftMs, inInclusiveRange(1500, 2500));
    });
  });
}
