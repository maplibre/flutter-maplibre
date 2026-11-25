part of 'map_options.dart';

/// The debug overlays that the map draws over itself, to find out why a
/// tile is missing or a label is hidden.
///
/// [MapDebugOverlays.none] turns them all off and is the default of
/// [MapOptions.debugOverlays]:
///
/// ```dart
/// MapOptions(
///   // Show why labels are hidden.
///   debugOverlays: MapDebugOverlays.none(collisionBoxes: true),
/// )
/// ```
///
/// {@category Basic}
@immutable
class MapDebugOverlays {
  /// Turns every overlay on by default.
  const MapDebugOverlays({
    this.tileBorders = true,
    this.collisionBoxes = true,
    this.overdraw = true,
    this.renderingStats = true,
  });

  /// Turns every overlay off by default.
  ///
  /// For example, `MapDebugOverlays.none(tileBorders: true)` only draws the
  /// tile borders.
  const MapDebugOverlays.none({
    this.tileBorders = false,
    this.collisionBoxes = false,
    this.overdraw = false,
    this.renderingStats = false,
  });

  /// Outlines each tile.
  final bool tileBorders;

  /// Draws the boxes and circles that symbol placement checks for
  /// collisions. A label or icon whose box is red is hidden because it
  /// collides with another one.
  final bool collisionBoxes;

  /// Shades each pixel by how often it was drawn: the more layers draw a
  /// pixel, the brighter it gets.
  final bool overdraw;

  /// Shows the rendering statistics of each frame, such as its draw calls
  /// and memory.
  ///
  /// Not on web, where it has no effect.
  final bool renderingStats;

  /// A copy with the given overlays replaced.
  MapDebugOverlays copyWith({
    bool? tileBorders,
    bool? collisionBoxes,
    bool? overdraw,
    bool? renderingStats,
  }) => MapDebugOverlays(
    tileBorders: tileBorders ?? this.tileBorders,
    collisionBoxes: collisionBoxes ?? this.collisionBoxes,
    overdraw: overdraw ?? this.overdraw,
    renderingStats: renderingStats ?? this.renderingStats,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapDebugOverlays &&
          tileBorders == other.tileBorders &&
          collisionBoxes == other.collisionBoxes &&
          overdraw == other.overdraw &&
          renderingStats == other.renderingStats;

  @override
  int get hashCode =>
      Object.hash(tileBorders, collisionBoxes, overdraw, renderingStats);

  @override
  String toString() =>
      'MapDebugOverlays(tileBorders: $tileBorders, '
      'collisionBoxes: $collisionBoxes, overdraw: $overdraw, '
      'renderingStats: $renderingStats)';
}
