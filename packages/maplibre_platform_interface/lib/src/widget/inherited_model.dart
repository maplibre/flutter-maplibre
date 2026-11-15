import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';
import 'package:maplibre_platform_interface/src/widget/map_plugin_registry.dart';

/// What a widget below a [MapLibreMap] depends on, so that it only rebuilds
/// when that changes.
enum MapLibreAspect {
  /// The [MapController], its [MapOptions] and its [StyleController].
  controller,

  /// The [CameraPosition], which changes with every frame of a camera move.
  camera,
}

/// The [InheritedModel] makes it possible to call `MapController.of(context)`.
///
/// https://api.flutter.dev/flutter/widgets/InheritedModel-class.html
class MapLibreInheritedModel extends InheritedModel<MapLibreAspect> {
  /// Default constructor
  const MapLibreInheritedModel({
    required super.child,
    required this.mapController,
    required this.cameraPosition,
    this.options,
    this.style,
    this.plugins,
    super.key,
  });

  /// [MapController] instance.
  final MapController mapController;

  /// [CameraPosition] instance.
  final CameraPosition? cameraPosition;

  /// The [MapController.options] when this model was built, so that the
  /// widgets that depend on the controller rebuild when they change.
  final MapOptions? options;

  /// The [MapController.style] when this model was built, so that the
  /// widgets that depend on the controller rebuild when it changes.
  final StyleController? style;

  /// The [MapPlugin]s below the map register here.
  final MapPluginRegistry? plugins;

  static MapLibreInheritedModel? _of(
    BuildContext context,
    MapLibreAspect aspect,
  ) => InheritedModel.inheritFrom<MapLibreInheritedModel>(
    context,
    aspect: aspect,
  );

  /// Get the in the widget tree injected [MapController]. The widget of
  /// [context] rebuilds when the controller, its options or its style
  /// change, but not when the camera moves.
  /// Used in [MapController.maybeOf] and [MapOptions.maybeOf].
  static MapController? maybeMapControllerOf(BuildContext context) =>
      _of(context, MapLibreAspect.controller)?.mapController;

  /// Get the in the widget tree injected [CameraPosition]. The widget of
  /// [context] rebuilds whenever the camera moves.
  /// Used in [CameraPosition.maybeOf].
  static CameraPosition? maybeCameraPositionOf(BuildContext context) =>
      _of(context, MapLibreAspect.camera)?.cameraPosition;

  /// The registry of the closest map, without depending on it.
  static MapPluginRegistry? maybePluginsOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MapLibreInheritedModel>()?.plugins;

  bool _controllerChanged(MapLibreInheritedModel oldWidget) =>
      !identical(mapController, oldWidget.mapController) ||
      options != oldWidget.options ||
      !identical(style, oldWidget.style);

  bool _cameraChanged(MapLibreInheritedModel oldWidget) =>
      cameraPosition != oldWidget.cameraPosition;

  @override
  bool updateShouldNotify(covariant MapLibreInheritedModel oldWidget) =>
      _controllerChanged(oldWidget) || _cameraChanged(oldWidget);

  @override
  bool updateShouldNotifyDependent(
    covariant MapLibreInheritedModel oldWidget,
    Set<MapLibreAspect> dependencies,
  ) =>
      (dependencies.contains(MapLibreAspect.controller) &&
          _controllerChanged(oldWidget)) ||
      (dependencies.contains(MapLibreAspect.camera) &&
          _cameraChanged(oldWidget));
}
