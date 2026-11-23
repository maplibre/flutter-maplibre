import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre/maplibre.dart';
import 'package:material_ui/material_ui.dart';

import 'shared/test_map.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runTests();
}

void runTests() {
  group('MapLibreMap', () {
    testWidgets('reports creation and the loaded style in order', (
      tester,
    ) async {
      final map = await pumpMap(tester);
      expect(map.lifecycle, [MapLifecycle.created, MapLifecycle.styleLoaded]);
      await tester.pump(const Duration(seconds: 1));
      expect(map.lifecycle, [MapLifecycle.created, MapLifecycle.styleLoaded]);
      expect(map.style.layers.map((layer) => layer.id).toList(), [
        'background',
      ]);
    });

    testWidgets('renders into a texture on native platforms', (tester) async {
      await pumpMap(tester);
      expect(
        find.descendant(
          of: find.byType(MapLibreMap),
          matching: find.byType(Texture),
        ),
        kIsWeb ? findsNothing : findsOneWidget,
      );
    }, skip: kIsWeb);

    testWidgets('shows its frames on screen', (tester) async {
      String style(String color) => jsonEncode({
        'version': 8,
        'sources': <String, Object>{},
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': color},
          },
        ],
      });
      final map = await pumpMap(
        tester,
        options: MapOptions(style: MapStyle.json(style('#ff0000'))),
      );
      await map.waitForColorAtCenter('red', 0);
      // A resize replaces the textures that the frames render into.
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = tester.view.physicalSize * 0.75;
      await map.setOptions(MapOptions(style: MapStyle.json(style('#0000ff'))));
      await map.waitForColorAtCenter('blue', 2);
    }, skip: kIsWeb);

    testWidgets('starts at the camera of its options', (tester) async {
      final map = await pumpMap(
        tester,
        options: offlineOptions(
          center: const Geographic(lon: 12, lat: 34),
          zoom: 5,
          bearing: 30,
          pitch: 20,
        ),
      );
      final camera = map.controller.getCamera();
      expect(camera.center.lon, closeTo(12, 1e-6));
      expect(camera.center.lat, closeTo(34, 1e-6));
      expect(camera.zoom, closeTo(5, 1e-6));
      expect(camera.bearing, closeTo(30, 1e-6));
      expect(camera.pitch, closeTo(20, 1e-6));
      expect(map.controller.camera, isNotNull);
    });

    testWidgets('exposes its options', (tester) async {
      final options = offlineOptions(minZoom: 1, maxZoom: 12);
      final map = await pumpMap(tester, options: options);
      expect(map.controller.options, options);
    });

    testWidgets('applies new options without recreating the map', (
      tester,
    ) async {
      final map = await pumpMap(tester, options: offlineOptions(zoom: 3));
      final updated = offlineOptions(zoom: 3, maxZoom: 5);
      await map.setOptions(updated);
      await tester.pump();

      expect(map.controller.options, updated);
      await map.controller.moveCamera(const CameraUpdate.position(zoom: 10));
      final camera = await map.waitForCamera((camera) => camera.zoom > 4);
      expect(camera.zoom, closeTo(5, 1e-6));
    });

    testWidgets('clamps the camera to the zoom and pitch limits', (
      tester,
    ) async {
      final map = await pumpMap(
        tester,
        options: MapOptions(
          style: MapStyle.json(offlineStyle),
          minZoom: 2,
          maxZoom: 6,
          maxPitch: 30,
          initCamera: const CameraUpdate.position(zoom: 3),
        ),
      );
      await map.controller.moveCamera(
        const CameraUpdate.position(zoom: 10, pitch: 60),
      );
      var camera = await map.waitForCamera((camera) => camera.zoom > 3);
      expect(camera.zoom, closeTo(6, 1e-6));
      expect(camera.pitch, closeTo(30, 1e-6));

      await map.controller.moveCamera(const CameraUpdate.position(zoom: 0));
      camera = await map.waitForCamera((camera) => camera.zoom < 6);
      expect(camera.zoom, closeTo(2, 1e-6));
    });

    testWidgets('loads a style set at runtime', (tester) async {
      final map = await pumpMap(tester);
      final since = map.styleLoads;
      await map.setOptions(
        const MapOptions(
          style: MapStyle.json(
            '{"version":8,"sources":{},"layers":[{"id":"other",'
            '"type":"background","paint":{"background-color":"#000000"}}]}',
          ),
        ),
      );
      await map.waitForStyleLoad(since: since);
      expect(map.controller.style?.layers.map((layer) => layer.id).toList(), [
        'other',
      ]);
    });

    testWidgets('keeps its style when other options change', (tester) async {
      final map = await pumpMap(tester);
      final since = map.styleLoads;
      await map.setOptions(offlineOptions(maxZoom: 10));
      await tester.pump(const Duration(milliseconds: 500));
      expect(map.styleLoads, since);
    });

    testWidgets('starts at the camera of its style', (tester) async {
      final map = await pumpMap(
        tester,
        options: MapOptions(style: MapStyle.json(_styleWithCamera)),
      );
      final camera = map.controller.getCamera();
      expect(camera.center.lon, closeTo(10, 1e-6));
      expect(camera.center.lat, closeTo(20, 1e-6));
      expect(camera.zoom, closeTo(5, 1e-6));
      expect(camera.bearing, closeTo(30, 1e-6));
      expect(camera.pitch, closeTo(20, 1e-6));
    });

    testWidgets('clamps the camera of its style to the zoom limits', (
      tester,
    ) async {
      final map = await pumpMap(
        tester,
        options: MapOptions(style: MapStyle.json(_styleWithCamera), maxZoom: 3),
      );
      final camera = await map.waitForCamera((camera) => camera.zoom < 5);
      expect(camera.zoom, closeTo(3, 1e-6));
      expect(camera.center.lon, closeTo(10, 1e-6));
    });

    testWidgets('prefers its initial camera over the style camera', (
      tester,
    ) async {
      final map = await pumpMap(
        tester,
        options: MapOptions(
          style: MapStyle.json(_styleWithCamera),
          initCamera: const CameraUpdate.position(
            center: Geographic(lon: -3, lat: 4),
            zoom: 2,
          ),
        ),
      );
      final camera = map.controller.getCamera();
      expect(camera.center.lon, closeTo(-3, 1e-6));
      expect(camera.center.lat, closeTo(4, 1e-6));
      expect(camera.zoom, closeTo(2, 1e-6));
      expect(camera.bearing, closeTo(0, 1e-6));
      expect(camera.pitch, closeTo(0, 1e-6));
    });

    testWidgets('starts fitted to its initial bounds', (tester) async {
      const bounds = GeoBox(west: -10, south: -5, east: 10, north: 5);
      final map = await pumpMap(
        tester,
        options: MapOptions(
          style: MapStyle.json(_styleWithCamera),
          initCamera: const CameraUpdate.bounds(
            bounds,
            padding: EdgeInsets.all(20),
          ),
        ),
      );
      // The first frame already shows the fitted camera.
      final shown = map.controller.camera!;
      expect(shown.center.lon, closeTo(0, 1e-6));
      expect(shown.center.lat, closeTo(0, 1e-6));
      final visible = map.controller.getVisibleBounds();
      expect(visible.west, lessThanOrEqualTo(bounds.west));
      expect(visible.east, greaterThanOrEqualTo(bounds.east));
      expect(visible.south, lessThanOrEqualTo(bounds.south));
      expect(visible.north, greaterThanOrEqualTo(bounds.north));
      // The bounds fill the map on one axis, up to the padding.
      final corner = map.controller.toScreenLocation(
        Geographic(lon: bounds.west, lat: bounds.north),
      );
      expect(min(corner.dx, corner.dy), closeTo(20, 1));
    });

    testWidgets('fits its initial bounds into a small map', (tester) async {
      const bounds = GeoBox(west: -10, south: -5, east: 10, north: 5);
      final controller = Completer<MapController>();
      final style = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: MapLibreMap(
                options: MapOptions(
                  style: MapStyle.json(offlineStyle),
                  initCamera: const CameraUpdate.bounds(bounds),
                ),
                onMapCreated: controller.complete,
                onStyleLoaded: (_) => style.complete(),
              ),
            ),
          ),
        ),
      );
      final map = await controller.future.timeout(defaultTimeout);
      await style.future.timeout(defaultTimeout);
      final deadline = DateTime.now().add(defaultTimeout);
      while (map.camera == null && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      final corner = map.toScreenLocation(
        Geographic(lon: bounds.west, lat: bounds.north),
      );
      // 20 by 10 degrees in a 300 by 200 map: the width fits exactly.
      expect(corner.dx, closeTo(0, 1));
      expect(corner.dy, greaterThan(0));
    });

    testWidgets('can be removed and shown again', (tester) async {
      await pumpMap(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      final map = await pumpMap(tester);
      expect(map.style.layers.map((layer) => layer.id).toList(), [
        'background',
      ]);
    });

    testWidgets('shows two maps with independent cameras', (tester) async {
      final controllers = [
        Completer<MapController>(),
        Completer<MapController>(),
      ];
      final styles = [Completer<void>(), Completer<void>()];
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              for (final (i, lon) in [(0, -40.0), (1, 40.0)])
                Expanded(
                  child: MapLibreMap(
                    options: offlineOptions(
                      center: Geographic(lon: lon, lat: 0),
                    ),
                    onMapCreated: controllers[i].complete,
                    onStyleLoaded: (_) => styles[i].complete(),
                  ),
                ),
            ],
          ),
        ),
      );
      final left = await controllers[0].future.timeout(defaultTimeout);
      final right = await controllers[1].future.timeout(defaultTimeout);
      await Future.wait(styles.map((style) => style.future))
          .timeout(defaultTimeout);

      expect(left.getCamera().center.lon, closeTo(-40, 1e-6));
      expect(right.getCamera().center.lon, closeTo(40, 1e-6));
      await left.moveCamera(const CameraUpdate.position(zoom: 6));
      await tester.pump(const Duration(milliseconds: 200));
      expect(left.getCamera().zoom, closeTo(6, 1e-6));
      expect(right.getCamera().zoom, closeTo(4, 1e-6));
    });

    testWidgets('captures the map from a frame callback', (tester) async {
      MapController? controller;
      Future<Uint8List?>? captured;
      final map = await pumpMap(
        tester,
        // A capture draws a frame on web, where a frame is reported here,
        // so a capture must not draw a frame of its own from this callback.
        onRenderFrame: (_) {
          if (controller == null || captured != null) return;
          captured = controller.takeSnapshot(pixelRatio: 1);
        },
      );
      controller = map.controller;
      // A frame of the map, which the native platforms only render once
      // something changed.
      await controller.moveCamera(const CameraUpdate.position(zoom: 3));
      await map.pumpUntil(
        () => captured != null,
        reason: () => 'the map never reported a frame',
      );
      expect(
        await map.pumpFuture(captured!, reason: 'capturing from a frame'),
        isNotNull,
      );
    });

    testWidgets('captures the map it shows', (tester) async {
      String background(String color) => jsonEncode({
        'version': 8,
        'sources': <String, Object>{},
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': color},
          },
        ],
      });
      final map = await pumpMap(
        tester,
        options: MapOptions(style: MapStyle.json(background('#00ff00'))),
        // Covers the middle of the map, and must not reach the capture.
        children: const [
          Center(
            child: ColoredBox(
              color: Color(0xffff0000),
              child: SizedBox.square(dimension: 64),
            ),
          ),
        ],
      );
      await map.waitForLatestFrame();

      Future<ui.Image> capture({double? pixelRatio}) async {
        final png = await map.pumpFuture(
          map.controller.takeSnapshot(pixelRatio: pixelRatio),
          reason: 'capturing the map',
        );
        expect(png, isNotNull);
        return decodeImageFromList(png!);
      }

      // The RGBA color at the center of a capture.
      Future<List<int>> centerOf(ui.Image image) async {
        final pixels = await image.toByteData();
        final middle =
            ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        return Uint8List.sublistView(pixels!, middle, middle + 4).toList();
      }

      // Browsers convert the colors of a canvas they read, so the channels
      // of a capture are not compared exactly.
      bool shows(List<int> center, List<int> rgb) =>
          center[3] == 0xff &&
          Iterable.generate(
            3,
            (i) => (center[i] - rgb[i]).abs() <= 2,
          ).every((ok) => ok);

      // Outside web, a capture holds the frame the map last showed, which a
      // frame it just rendered only reaches a few frames later, so the map
      // is captured until a capture shows the background of its style.
      Future<ui.Image> captureUntil(List<int> rgb) async {
        final deadline = DateTime.now().add(defaultTimeout);
        ui.Image? image;
        while (true) {
          image?.dispose();
          image = await capture(pixelRatio: 1);
          final center = await centerOf(image);
          if (shows(center, rgb)) return image;
          if (DateTime.now().isAfter(deadline)) {
            final shown = kIsWeb
                ? 'the map on screen cannot be read on web'
                : 'the map on screen showed ${await map.pixelAtCenter()}';
            image.dispose();
            fail(
              'The capture never showed $rgb at the center of the map, '
              'last: $center, while $shown',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // The background of the style, under the widget over the map, which
      // the capture leaves out.
      final image = await captureUntil([0, 0xff, 0]);
      addTearDown(image.dispose);
      // A capture rounds the size up to the next whole pixel.
      expect(image.width, map.size.width.ceil());
      expect(image.height, map.size.height.ceil());

      // A capture scales with the pixel ratio asked for, whatever ratio the
      // map renders in.
      final larger = await capture(pixelRatio: 2);
      addTearDown(larger.dispose);
      expect(larger.width, (map.size.width * 2).ceil());
      expect(larger.height, (map.size.height * 2).ceil());
      final scaled = await centerOf(larger);
      expect(
        shows(scaled, [0, 0xff, 0]),
        isTrue,
        reason: 'the capture at twice the resolution showed $scaled',
      );

      // Without a ratio, a capture has the resolution of the screen.
      final screen = await capture();
      addTearDown(screen.dispose);
      final ratio = tester.view.devicePixelRatio;
      expect(screen.width, (map.size.width * ratio).ceil());
      expect(screen.height, (map.size.height * ratio).ceil());

      // A capture shows the map as it is, not a frame it showed before.
      await map.setOptions(
        MapOptions(style: MapStyle.json(background('#0000ff'))),
      );
      (await captureUntil([0, 0, 0xff])).dispose();
    });
  });
}

/// A style without network resources that stores a camera.
final String _styleWithCamera = jsonEncode({
  'version': 8,
  'center': [10, 20],
  'zoom': 5,
  'bearing': 30,
  'pitch': 20,
  'sources': <String, Object>{},
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#dddddd'},
    },
  ],
});
