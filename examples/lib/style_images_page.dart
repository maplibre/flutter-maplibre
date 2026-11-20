import 'dart:ui' as ui;

import 'package:maplibre/maplibre.dart';
import 'package:material_ui/material_ui.dart';

/// Animates an icon with [StyleController.updateImageFromUiImage] and adds
/// the icons of a layer on demand with [MapLibreMap.resolveStyleImage].
@immutable
class StyleImagesPage extends StatefulWidget {
  const StyleImagesPage({super.key});

  static const location = '/style-images';

  @override
  State<StyleImagesPage> createState() => _StyleImagesPageState();
}

class _StyleImagesPageState extends State<StyleImagesPage>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addListener(_updatePulse);
  StyleController? _style;
  var _updating = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Style Images')),
    body: MapLibreMap(
      options: const MapOptions(
        initCamera: CameraUpdate.position(
          zoom: 4,
          center: Geographic(lon: 9.17, lat: 47.68),
        ),
      ),
      onStyleLoaded: _onStyleLoaded,
      // Adds the pin of a color, such as "pin-ff43a047", once a layer needs it.
      resolveStyleImage: (style, id) async {
        if (!id.startsWith('pin-')) return;
        await style.addImageFromIconData(
          id: id,
          iconData: Icons.location_on,
          color: Color(int.parse(id.substring(4), radix: 16)),
        );
      },
    ),
  );

  Future<void> _onStyleLoaded(StyleController style) async {
    _style = style;
    final dot = await _pulseImage(0);
    await style.addImageFromUiImage(id: 'pulse', image: dot, pixelRatio: 2);
    dot.dispose();
    await style.sources.add(
      const GeoJsonSource.data(
        id: 'points',
        data: .json({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {'icon': 'pulse'},
              'geometry': {
                'type': 'Point',
                'coordinates': [9.17, 47.68],
              },
            },
            {
              'type': 'Feature',
              'properties': {'icon': 'pin-ffe53935'},
              'geometry': {
                'type': 'Point',
                'coordinates': [8.53, 47.38],
              },
            },
            {
              'type': 'Feature',
              'properties': {'icon': 'pin-ff43a047'},
              'geometry': {
                'type': 'Point',
                'coordinates': [11.58, 48.14],
              },
            },
          ],
        }),
      ),
    );
    await style.layers.add(
      SymbolStyleLayer(
        id: 'points',
        sourceId: 'points',
        iconImage: Expression.get('icon').asString(),
        iconAllowOverlap: const .literal(true),
      ),
    );
    if (mounted) _pulse.repeat();
  }

  /// Draws the next frame of the pulse, unless the last one is still on its
  /// way to the map.
  Future<void> _updatePulse() async {
    final style = _style;
    if (style == null || _updating) return;
    _updating = true;
    final frame = await _pulseImage(_pulse.value);
    try {
      await style.updateImageFromUiImage(id: 'pulse', image: frame);
    } finally {
      frame.dispose();
      _updating = false;
    }
  }

  /// A blue dot with a ring that grows and fades as [t] goes from 0 to 1.
  static Future<ui.Image> _pulseImage(double t) {
    const size = 96;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawCircle(
        center,
        size / 2 * (0.3 + 0.7 * t),
        Paint()..color = Colors.blue.withValues(alpha: 1 - t),
      )
      ..drawCircle(center, size * 0.15, Paint()..color = Colors.white)
      ..drawCircle(center, size * 0.11, Paint()..color = Colors.blue);
    final picture = recorder.endRecording();
    final image = picture.toImage(size, size);
    picture.dispose();
    return image;
  }
}
