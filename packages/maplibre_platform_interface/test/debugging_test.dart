import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

void main() {
  group('MapDebugOverlays', () {
    test('turn every overlay on, or none with .none()', () {
      const all = MapDebugOverlays();
      expect([
        all.tileBorders,
        all.collisionBoxes,
        all.overdraw,
        all.renderingStats,
      ], everyElement(isTrue));
      const none = MapDebugOverlays.none(collisionBoxes: true);
      expect(none.collisionBoxes, isTrue);
      expect([
        none.tileBorders,
        none.overdraw,
        none.renderingStats,
      ], everyElement(isFalse));
    });

    test('are off in the default MapOptions', () {
      expect(const MapOptions().debugOverlays, const MapDebugOverlays.none());
    });

    test('compare by value, also in MapOptions', () {
      const a = MapDebugOverlays.none(tileBorders: true);
      expect(a, const MapDebugOverlays.none().copyWith(tileBorders: true));
      expect(
        a.hashCode,
        const MapDebugOverlays.none().copyWith(tileBorders: true).hashCode,
      );
      expect(a, isNot(const MapDebugOverlays.none()));
      expect(const MapOptions(debugOverlays: a), isNot(const MapOptions()));
      expect(
        const MapOptions(debugOverlays: a),
        const MapOptions(
          debugOverlays: MapDebugOverlays.none(tileBorders: true),
        ),
      );
    });
  });

  group('MapLibreLog', () {
    tearDown(() => MapLibreLog.onMessage = null);

    const message = MapLogMessage(
      severity: .warning,
      category: .httpRequest,
      message: 'Request failed',
      code: 404,
    );

    test('passes messages to onMessage while it is set', () {
      final received = <MapLogMessage>[];
      MapLibreLog.log(message);
      MapLibreLog.onMessage = received.add;
      MapLibreLog.log(message);
      MapLibreLog.onMessage = null;
      MapLibreLog.log(message);
      expect(received, [message]);
    });

    test('notifies the platforms only when onMessage changes', () {
      var changes = 0;
      void listener() => changes++;
      MapLibreLog.changes.addListener(listener);
      addTearDown(() => MapLibreLog.changes.removeListener(listener));
      void callback(MapLogMessage _) {}
      MapLibreLog.onMessage = callback;
      MapLibreLog.onMessage = callback;
      MapLibreLog.onMessage = null;
      expect(changes, 2);
    });

    test('reports errors of onMessage to FlutterError.onError', () {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      MapLibreLog.onMessage = (_) => throw StateError('boom');
      MapLibreLog.log(message);
      expect(errors.single.exception, isStateError);
    });
  });
}
