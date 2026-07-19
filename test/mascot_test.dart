import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatt/core/mascot/mascot_state.dart';
import 'package:hatt/core/mascot/mascot_view.dart';

void main() {
  testWidgets('every MascotState has a decodable asset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    await tester.runAsync(() async {
      for (final state in MascotState.values) {
        // Throws if the asset is missing from the bundle or not a valid image.
        await precacheImage(AssetImage(state.asset), context);
      }
    });
  });

  testWidgets('normal state blinks periodically and reopens eyes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MascotView(size: 120))),
    );
    String asset() =>
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName;
    expect(asset(), MascotState.normal.asset);

    // A blink is scheduled 2.6–5.0s out and lasts 140ms; sampling every
    // 100ms over 6s must observe it.
    var blinked = false;
    for (var i = 0; i < 60 && !blinked; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (asset() == mascotClosedEyesAsset) blinked = true;
    }
    expect(blinked, isTrue, reason: 'mascot never blinked within 6s');

    await tester.pump(const Duration(milliseconds: 200));
    expect(
      asset(),
      MascotState.normal.asset,
      reason: 'eyes should reopen after the blink',
    );

    // Dispose the widget so the pending blink timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('renders all mascot states side by side (golden)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 200));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFF6EFE2),
          body: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final state in MascotState.values)
                MascotView(state: state, size: 160, animated: false),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    await tester.runAsync(() async {
      for (final state in MascotState.values) {
        await precacheImage(AssetImage(state.asset), context);
      }
    });
    await tester.pump();
    await expectLater(
      find.byType(Row),
      matchesGoldenFile('goldens/mascot_states.png'),
    );
  });
}
