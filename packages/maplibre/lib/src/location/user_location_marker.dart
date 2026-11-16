import 'package:flutter/widgets.dart';
import 'package:maplibre/maplibre.dart';

/// How a [UserLocationLayer] draws the user location, see
/// [UserLocationLayer.marker].
///
/// {@category Location}
@immutable
sealed class UserLocationMarker {
  const UserLocationMarker._();

  /// Draws the location with style layers of the map: an accuracy circle, a
  /// heading cone and a dot, in [UserLocationLayer.color] and
  /// [UserLocationLayer.radius]. The default.
  ///
  /// The map draws them in the same frame as everything else, so they never
  /// lag behind the camera. The accuracy circle and the heading lie flat on
  /// the map when it is tilted, and [anchor] places them among the layers
  /// of the style, for example below its labels.
  ///
  /// [icon] replaces the dot, for example with an arrow, and turns with the
  /// heading while [rotateIcon] is set. [onClick] is called when the user
  /// taps the location.
  const factory UserLocationMarker.style({
    LayerAnchor anchor,
    MarkerIcon? icon,
    bool rotateIcon,
    bool showAccuracy,
    bool showHeading,
    ValueChanged<UserLocation>? onClick,
  }) = UserLocationMarkerStyle;

  /// Paints the location with Flutter over the map, in
  /// [UserLocationLayer.color] and [UserLocationLayer.radius].
  ///
  /// The painting follows the frame on screen, but on web it can trail
  /// camera animations, such as those of the tracking, and it always stays
  /// above the whole map.
  const factory UserLocationMarker.painted() = UserLocationMarkerPainted;

  /// Shows the widget that [builder] builds for each location, centered on
  /// the location. It has the same limits as [UserLocationMarker.painted].
  const factory UserLocationMarker.widget(
    Widget Function(BuildContext context, UserLocation location) builder,
  ) = UserLocationMarkerWidget;
}

/// See [UserLocationMarker.style].
///
/// {@category Location}
final class UserLocationMarkerStyle extends UserLocationMarker {
  /// See [UserLocationMarker.style].
  const UserLocationMarkerStyle({
    this.anchor = const LayerAnchor.top(),
    this.icon,
    this.rotateIcon = true,
    this.showAccuracy = true,
    this.showHeading = true,
    this.onClick,
  }) : super._();

  /// Where the layers of the marker go among the layers of the style, on
  /// top of them by default, see [Layer.anchor].
  final LayerAnchor anchor;

  /// The image that replaces the dot, or null for the dot.
  final MarkerIcon? icon;

  /// Whether [icon] turns with the heading of the location. Defaults to
  /// true.
  final bool rotateIcon;

  /// Whether the accuracy of the location shows as a circle around it.
  /// Defaults to true.
  final bool showAccuracy;

  /// Whether the heading of the location shows as a cone. Defaults to true.
  final bool showHeading;

  /// Called when the user taps or clicks the location.
  final ValueChanged<UserLocation>? onClick;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLocationMarkerStyle &&
          anchor == other.anchor &&
          icon == other.icon &&
          rotateIcon == other.rotateIcon &&
          showAccuracy == other.showAccuracy &&
          showHeading == other.showHeading &&
          onClick == other.onClick;

  @override
  int get hashCode =>
      Object.hash(anchor, icon, rotateIcon, showAccuracy, showHeading, onClick);
}

/// See [UserLocationMarker.painted].
///
/// {@category Location}
final class UserLocationMarkerPainted extends UserLocationMarker {
  /// See [UserLocationMarker.painted].
  const UserLocationMarkerPainted() : super._();

  @override
  bool operator ==(Object other) => other is UserLocationMarkerPainted;

  @override
  int get hashCode => (UserLocationMarkerPainted).hashCode;
}

/// See [UserLocationMarker.widget].
///
/// {@category Location}
final class UserLocationMarkerWidget extends UserLocationMarker {
  /// See [UserLocationMarker.widget].
  const UserLocationMarkerWidget(this.builder) : super._();

  /// Builds the widget for a location.
  final Widget Function(BuildContext context, UserLocation location) builder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLocationMarkerWidget && builder == other.builder;

  @override
  int get hashCode => builder.hashCode;
}
