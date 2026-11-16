import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:maplibre/maplibre.dart';
import 'package:maplibre/src/location/user_location_style_layers.dart';

/// Meters per degree of latitude.
const _metersPerDegree = 111320.0;

/// Shows the user location on the [MapLibreMap] by using it in
/// [MapLibreMap.children], and moves the camera with it while [tracking].
/// It is a [MapPlugin] of the map.
///
/// The layer takes its locations from a stream, so it works the same on
/// every platform and with any location source. It asks for no permission;
/// use a package such as `permission_handler` or `geolocator` for that, and
/// `maplibre_geolocator` to turn `geolocator` positions into locations.
///
/// A gesture that moves the map, such as a drag, a pinch or a scroll wheel
/// zoom, stops the tracking and reports [UserLocationTracking.none] to
/// [onTrackingChanged].
///
/// [marker] chooses how the location is drawn: with style layers of the map
/// by default, painted over the map, or as a widget.
///
/// {@category Location}
class UserLocationLayer extends StatefulWidget {
  /// Creates a layer that shows the latest of [locations].
  const UserLocationLayer({
    required this.locations,
    this.tracking = UserLocationTracking.none,
    this.onTrackingChanged,
    this.trackingZoom,
    this.trackingDuration = const Duration(milliseconds: 500),
    this.color = const Color(0xFF1A73E8),
    this.radius = 8,
    this.marker = const UserLocationMarker.style(),
    super.key,
  });

  /// The locations of the user. The layer shows the latest one.
  final Stream<UserLocation> locations;

  /// How the camera moves with the user location.
  final UserLocationTracking tracking;

  /// Called when the tracking changes because the user moved the map.
  final ValueChanged<UserLocationTracking>? onTrackingChanged;

  /// The zoom the camera moves to when the tracking starts, or null to keep
  /// the zoom.
  final double? trackingZoom;

  /// How long the camera takes to follow a new location.
  final Duration trackingDuration;

  /// The color of the location dot, its accuracy circle and its heading.
  final Color color;

  /// The radius of the location dot in logical pixels.
  final double radius;

  /// How the location is drawn, with style layers of the map by default.
  final UserLocationMarker marker;

  @override
  State<UserLocationLayer> createState() => _UserLocationLayerState();
}

class _UserLocationLayerState extends State<UserLocationLayer> {
  StreamSubscription<UserLocation>? _subscription;
  UserLocation? _location;
  late UserLocationTracking _tracking = widget.tracking;

  /// Whether the camera has moved to the location since the tracking
  /// started, so [UserLocationLayer.trackingZoom] applies only once.
  var _tracked = false;

  /// The PNGs of the heading cone, by color.
  static final _headingImages = <Color, Future<Uint8List>>{};

  /// The heading cone in [UserLocationLayer.color], once it is drawn.
  Uint8List? _headingImage;
  Color? _headingColor;

  /// The layers of a [UserLocationMarkerStyle] and what they were made of,
  /// so that a rebuild hands the plugin the same layers while nothing
  /// changed.
  List<Layer> _layers = const [];
  Object? _layersInputs;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(UserLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locations != oldWidget.locations) {
      unawaited(_subscription?.cancel());
      _subscribe();
    }
    if (widget.tracking != oldWidget.tracking) {
      _tracking = widget.tracking;
      _tracked = false;
      _follow();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _subscribe() {
    _subscription = widget.locations.listen((location) {
      if (!mounted) return;
      setState(() => _location = location);
      _follow();
    });
  }

  /// Moves the camera to the latest location while tracking.
  void _follow() {
    final location = _location;
    final controller = MapController.maybeOf(context);
    if (location == null ||
        controller == null ||
        _tracking == UserLocationTracking.none) {
      return;
    }
    final zoom = _tracked ? null : widget.trackingZoom;
    _tracked = true;
    unawaited(
      controller.animateCamera(
        CameraUpdate.position(
          center: location.position,
          zoom: zoom,
          bearing: _tracking == UserLocationTracking.positionAndHeading
              ? location.heading
              : null,
        ),
        animation: CameraAnimation.fly(duration: widget.trackingDuration),
      ),
    );
  }

  /// Stops the tracking when the user moves the map.
  void _onCameraMoveStart(MapEventCameraMoveStart event) {
    if (event.reason != CameraChangeReason.gesture ||
        _tracking == UserLocationTracking.none) {
      return;
    }
    _tracking = UserLocationTracking.none;
    widget.onTrackingChanged?.call(UserLocationTracking.none);
  }

  /// Draws the heading cone in [color] for the style layers, once per color.
  void _loadHeadingImage(Color color) {
    if (_headingColor == color) return;
    _headingColor = color;
    _headingImage = null;
    final image = _headingImages[color] ??= drawHeadingImage(color);
    unawaited(
      image.then(
        (bytes) {
          if (mounted && _headingColor == color) {
            setState(() => _headingImage = bytes);
          }
        },
        onError: (Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'maplibre',
              context: ErrorDescription(
                'while drawing the user location heading',
              ),
            ),
          );
        },
      ),
    );
  }

  /// The layers that show the location with a [UserLocationMarkerStyle].
  List<Layer> _styleLayers(UserLocationMarkerStyle marker) {
    final location = _location;
    if (location == null) return const [];
    if (marker.showHeading) _loadHeadingImage(widget.color);
    final inputs = (
      location,
      marker,
      widget.color,
      widget.radius,
      _headingImage,
    );
    if (inputs != _layersInputs) {
      _layersInputs = inputs;
      _layers = userLocationStyleLayers(
        location: location,
        marker: marker,
        color: widget.color,
        radius: widget.radius,
        headingImage: _headingImage,
      );
    }
    return _layers;
  }

  @override
  Widget build(BuildContext context) {
    final marker = widget.marker;
    return MapPlugin(
      onCameraMoveStart: _onCameraMoveStart,
      layers: switch (marker) {
        final UserLocationMarkerStyle marker => _styleLayers(marker),
        _ => const [],
      },
      child: switch (marker) {
        UserLocationMarkerStyle() => null,
        UserLocationMarkerPainted() => _UserLocationPaint(
          location: _location,
          color: widget.color,
          radius: widget.radius,
        ),
        UserLocationMarkerWidget(:final builder) => _UserLocationWidget(
          location: _location,
          builder: builder,
        ),
      },
    );
  }
}

/// Paints [location] over the map. It rebuilds with every frame of a
/// camera move, unlike the layer around it.
class _UserLocationPaint extends StatelessWidget {
  const _UserLocationPaint({
    required this.location,
    required this.color,
    required this.radius,
  });

  final UserLocation? location;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final controller = MapController.maybeOf(context);
    final camera = CameraPosition.maybeOf(context);
    final location = this.location;
    _UserLocationPainter? painter;
    if (controller != null && camera != null && location != null) {
      final accuracy = location.accuracy;
      // The screen distance to a point the accuracy north, so the circle
      // follows the zoom, the latitude and the projection.
      final points = controller.toScreenLocations([
        location.position,
        if (accuracy != null && accuracy > 0)
          Geographic(
            lon: location.position.lon,
            lat: min(90, location.position.lat + accuracy / _metersPerDegree),
          ),
      ]);
      final heading = location.heading;
      painter = _UserLocationPainter(
        center: points.first,
        accuracyRadius: points.length > 1
            ? (points[1] - points[0]).distance
            : 0,
        heading: heading == null ? null : heading - camera.bearing,
        color: color,
        radius: radius,
      );
    }
    return IgnorePointer(
      child: CustomPaint(painter: painter, size: Size.infinite),
    );
  }
}

/// Shows the widget of [builder] centered on [location]. It rebuilds with
/// every frame of a camera move, unlike the layer around it.
class _UserLocationWidget extends StatelessWidget {
  const _UserLocationWidget({required this.location, required this.builder});

  final UserLocation? location;
  final Widget Function(BuildContext context, UserLocation location) builder;

  @override
  Widget build(BuildContext context) {
    final controller = MapController.maybeOf(context);
    final location = this.location;
    // Only to rebuild when the camera moves.
    final camera = CameraPosition.maybeOf(context);
    if (controller == null || camera == null || location == null) {
      return const SizedBox.shrink();
    }
    final center = controller.toScreenLocation(location.position);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: center.dx,
            top: center.dy,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: builder(context, location),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserLocationPainter extends CustomPainter {
  const _UserLocationPainter({
    required this.center,
    required this.accuracyRadius,
    required this.heading,
    required this.color,
    required this.radius,
  });

  final Offset center;
  final double accuracyRadius;

  /// The heading on screen, in degrees clockwise from up.
  final double? heading;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (accuracyRadius > radius) {
      canvas
        ..drawCircle(
          center,
          accuracyRadius,
          Paint()..color = color.withValues(alpha: 0.15),
        )
        ..drawCircle(
          center,
          accuracyRadius,
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke,
        );
    }
    if (heading case final double heading) {
      // A cone of 60 degrees toward the heading.
      final direction = (heading - 90) * pi / 180;
      final length = radius * 4;
      final cone = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: length),
          direction - pi / 6,
          pi / 3,
          false,
        )
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: length)),
      );
    }
    canvas
      ..drawCircle(center, radius + 2, Paint()..color = const Color(0xFFFFFFFF))
      ..drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_UserLocationPainter oldDelegate) =>
      center != oldDelegate.center ||
      accuracyRadius != oldDelegate.accuracyRadius ||
      heading != oldDelegate.heading ||
      color != oldDelegate.color ||
      radius != oldDelegate.radius;
}
