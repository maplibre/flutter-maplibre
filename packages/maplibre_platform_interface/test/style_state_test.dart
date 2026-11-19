import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

import 'shared/recording_style_backend.dart';

void main() {
  late RecordingStyleBackend backend;

  setUp(() => backend = RecordingStyleBackend());

  group('feature state', () {
    late StyleSources sources;

    setUp(() async {
      sources = StyleSources(backend, layers: () => const []);
      await sources.add(const GeoJsonSource.url(id: 'g', url: 'https://g'));
      await sources.add(const VectorSource.url(id: 'v', url: 'https://v'));
      await sources.add(const RasterSource.url(id: 'r', url: 'https://r'));
      backend.calls.clear();
    });

    test('merges keys and reads them back', () {
      const feature = FeatureRef(sourceId: 'g', id: 1);
      expect(sources.featureState(feature), isEmpty);
      sources
        ..setFeatureState(feature, {'hover': true, 'rank': 2})
        ..setFeatureState(feature, {'hover': false});
      expect(sources.featureState(feature), {'hover': false, 'rank': 2});
      expect(
        sources.featureState(const FeatureRef(sourceId: 'g', id: 2)),
        isEmpty,
      );
      expect(backend.calls, [
        'setFeatureState FeatureRef(g, 1) {hover: true, rank: 2}',
        'setFeatureState FeatureRef(g, 1) {hover: false}',
      ]);
    });

    test('keeps source layers apart', () {
      const a = FeatureRef(sourceId: 'v', sourceLayer: 'a', id: 'x');
      const b = FeatureRef(sourceId: 'v', sourceLayer: 'b', id: 'x');
      sources.setFeatureState(a, {'on': true});
      expect(sources.featureState(a), {'on': true});
      expect(sources.featureState(b), isEmpty);
      sources.clearFeatureState('v', sourceLayer: 'a');
      expect(sources.featureState(a), isEmpty);
      expect(backend.calls.last, 'removeFeatureState v a null null');
    });

    test('removes one key, one feature or every feature', () {
      const one = FeatureRef(sourceId: 'g', id: 1);
      const two = FeatureRef(sourceId: 'g', id: 2);
      sources
        ..setFeatureState(one, {'hover': true, 'selected': true})
        ..setFeatureState(two, {'hover': true})
        ..removeFeatureState(one, key: 'hover');
      expect(sources.featureState(one), {'selected': true});
      sources.removeFeatureState(one);
      expect(sources.featureState(one), isEmpty);
      expect(sources.featureState(two), {'hover': true});
      sources.clearFeatureState('g');
      expect(sources.featureState(two), isEmpty);
      expect(backend.calls.skip(2), [
        'removeFeatureState g null 1 hover',
        'removeFeatureState g null 1 null',
        'removeFeatureState g null null null',
      ]);
    });

    test('goes with its source', () async {
      const feature = FeatureRef(sourceId: 'g', id: 1);
      sources.setFeatureState(feature, {'hover': true});
      await sources.remove('g');
      await sources.add(const GeoJsonSource.url(id: 'g', url: 'https://g'));
      expect(sources.featureState(feature), isEmpty);
    });

    test('checks the source and its source layer', () {
      for (final feature in const [
        FeatureRef(sourceId: 'missing', id: 1),
        FeatureRef(sourceId: 'v', id: 1),
        FeatureRef(sourceId: 'g', sourceLayer: 'a', id: 1),
        FeatureRef(sourceId: 'r', id: 1),
      ]) {
        expect(
          () => sources.setFeatureState(feature, {'a': 1}),
          throwsArgumentError,
          reason: '$feature',
        );
        expect(() => sources.featureState(feature), throwsArgumentError);
      }
      expect(() => sources.clearFeatureState('v'), throwsArgumentError);
      expect(backend.calls, isEmpty);
    });

    test('a replaced style takes no change', () {
      const feature = FeatureRef(sourceId: 'g', id: 1);
      sources
        ..markReplaced()
        ..setFeatureState(feature, {'hover': true});
      expect(sources.featureState(feature), isEmpty);
      expect(backend.calls, isEmpty);
    });

    test('refers to a rendered feature', () {
      expect(
        FeatureRef.of(
          const RenderedFeature(
            id: 7,
            properties: {},
            sourceId: 'v',
            sourceLayer: 'roads',
          ),
        ),
        const FeatureRef(sourceId: 'v', sourceLayer: 'roads', id: 7),
      );
      expect(
        FeatureRef.of(
          const RenderedFeature(
            id: 7,
            properties: {},
            sourceId: 'g',
            sourceLayer: '',
          ),
        ),
        const FeatureRef(sourceId: 'g', id: 7),
      );
      expect(
        () => FeatureRef.of(
          const RenderedFeature(id: null, properties: {}, sourceId: 'g'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('global state', () {
    late StyleGlobalState state;

    setUp(() {
      state = StyleGlobalState(backend)
        ..load({
          'units': {'default': 'metric'},
          'theme': {'default': 'day'},
        });
    });

    test('reads the defaults, overridden by the values', () {
      expect(state, {'units': 'metric', 'theme': 'day'});
      state.apply({'units': 'imperial', 'extra': 1});
      expect(state, {'units': 'imperial', 'theme': 'day', 'extra': 1});
      expect(() => state['units'] = 'x', throwsUnsupportedError);
    });

    test('sends only what changed, and defaults for removed values', () {
      state.apply({'units': 'imperial', 'theme': 'night'});
      state.apply({
        'units': 'imperial',
        'theme': null,
        'list': [1, 2],
      });
      state.apply({
        'units': 'imperial',
        'list': [1, 2],
      });
      state.apply(const {});
      expect(backend.calls, [
        'setGlobalStateProperty units imperial',
        'setGlobalStateProperty theme night',
        'setGlobalStateProperty theme day',
        'setGlobalStateProperty list [1, 2]',
        'setGlobalStateProperty units metric',
        'setGlobalStateProperty list null',
      ]);
      expect(state, {'units': 'metric', 'theme': 'day'});
    });

    test('a replaced style takes no change', () {
      state
        ..markReplaced()
        ..apply({'units': 'imperial'});
      expect(backend.calls, isEmpty);
      expect(state['units'], 'metric');
    });
  });

  group('light', () {
    test('reads the style light and sends the whole light', () {
      final light = StyleLight(backend)
        ..load({'anchor': 'map', 'intensity': 0.2});
      expect(light.anchor, const Literal(LightAnchor.map));
      expect(light.intensity, const Literal(0.2));
      expect(light.color, const Literal(Color(0xFFFFFFFF)));
      expect(light.position, const Literal(<num>[1.15, 210, 30]));
      light
        ..color = const .literal(Color(0xFFFF0000))
        ..intensityTransition = const StyleTransition(
          duration: Duration(seconds: 1),
        )
        ..anchor = null;
      expect(light.anchor, const Literal(LightAnchor.viewport));
      expect(light.intensityTransition?.duration, const Duration(seconds: 1));
      expect(
        backend.calls.last,
        'setLight {intensity: 0.2, color: #ff0000, '
        'intensity-transition: {duration: 1000, delay: 0}}',
      );
      expect(backend.calls, hasLength(3));
    });

    test('a replaced style takes no change', () {
      final light = StyleLight(backend)
        ..load(null)
        ..markReplaced()
        ..intensity = const .literal(1);
      expect(light.intensity, const Literal(1));
      expect(backend.calls, isEmpty);
    });
  });

  test('MapOptions compare global state deeply', () {
    // Built at run time, so that they are not identical.
    MapOptions options() => MapOptions(globalState: {'a': List.filled(1, 1)});
    expect(options(), options());
    expect(options().hashCode, options().hashCode);
    expect(
      const MapOptions(globalState: {'a': 1}),
      isNot(const MapOptions(globalState: {'a': 2})),
    );
  });
}
