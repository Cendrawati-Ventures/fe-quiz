import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_exam_system/shared/components/app_exit_confirmation.dart';

void main() {
  testWidgets('exit aplikasi harus dikonfirmasi', (tester) async {
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmExitApp(context),
            child: const Text('Keluar'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Keluar Aplikasi'), findsOneWidget);
    expect(find.text('Tidak'), findsOneWidget);
    expect(find.text('Ya, Keluar'), findsOneWidget);

    await tester.tap(find.text('Tidak'));
    await tester.pumpAndSettle();

    expect(find.text('Keluar Aplikasi'), findsNothing);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Keluar'));
    await tester.pumpAndSettle();

    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      hasLength(1),
    );
  });
}
