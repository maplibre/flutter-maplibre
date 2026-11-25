import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_native/src/extensions.dart';
import 'package:maplibre_native/src/logging.dart';
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

void main() {
  test('debug overlays convert to the debug flags of the C API', () {
    expect(const MapDebugOverlays.none().toMln(), mln.MapDebugFlag.none);
    expect(
      const MapDebugOverlays().toMln(),
      mln.MapDebugFlag.tileBorders |
          mln.MapDebugFlag.collision |
          mln.MapDebugFlag.overdraw,
    );
  });

  test('log events convert to categories, unknown ones to general', () {
    expect(
      mln.LogEvent.httpRequest.toMapLogCategory(),
      MapLogCategory.httpRequest,
    );
    expect(mln.LogEvent.timing.toMapLogCategory(), MapLogCategory.timing);
    expect(
      const mln.LogEvent.fromRawValue(999).toMapLogCategory(),
      MapLogCategory.general,
    );
    expect(mln.LogSeverity.warning.toMapLogSeverity(), MapLogSeverity.warning);
  });

  test('passes the log of the C library to MapLibreLog', () async {
    final messages = <MapLogMessage>[];
    listenToLog();
    MapLibreLog.onMessage = messages.add;
    addTearDown(() => MapLibreLog.onMessage = null);

    final runtime = mln.RuntimeHandle.create();
    final map = runtime.createMap(
      const mln.MapOptions(
        initialExtent: mln.LogicalExtent(
          width: 256,
          height: 256,
          scaleFactor: 1,
        ),
      ),
    );
    await map.ready;
    await map.setDebugFlags(const MapDebugOverlays().toMln());
    await map.dumpDebugLogs();
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (messages.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(messages, isNotEmpty);
    expect(map.getSnapshot().debugFlags, const MapDebugOverlays().toMln());

    await map.release();
    await runtime.release();
  });
}
