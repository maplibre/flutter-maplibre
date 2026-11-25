import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre/maplibre.dart';

import 'shared/test_map.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runTests();
}

void runTests() {
  group('debugging', () {
    tearDown(() => MapLibreLog.onMessage = null);

    testWidgets('turns debug overlays on and off', (tester) async {
      final map = await pumpMap(
        tester,
        options: offlineOptions(
          debugOverlays: const MapDebugOverlays.none(tileBorders: true),
        ),
      );
      await map.setOptions(
        offlineOptions(debugOverlays: const MapDebugOverlays()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await map.setOptions(offlineOptions());
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        map.controller.options.debugOverlays,
        const MapDebugOverlays.none(),
      );
      // The overlays draw text, which asks the offline style, which has no
      // glyphs, for glyphs on some platforms.
      expect(
        map.events.whereType<MapEventError>().where(
          (error) => error.kind != MapErrorKind.glyphs,
        ),
        isEmpty,
      );
    });

    testWidgets('dumps the debug logs into MapLibreLog', (tester) async {
      final messages = <MapLogMessage>[];
      MapLibreLog.onMessage = messages.add;
      final map = await pumpMap(tester);
      await map.pumpFuture(
        map.controller.dumpDebugLogs(),
        reason: 'dumpDebugLogs never completed',
      );
      if (kIsWeb) {
        // gl-js has no log.
        expect(messages, isEmpty);
        return;
      }
      await map.pumpUntil(
        () => messages.isNotEmpty,
        reason: () => 'no log message arrived',
      );
    });
  });
}
