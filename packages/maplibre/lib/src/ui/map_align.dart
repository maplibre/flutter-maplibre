import 'package:flutter/widgets.dart';
import 'package:maplibre/maplibre.dart';

/// Stacks widgets of [MapLibreMap.children] at one [alignment] of the map,
/// so that several of them share a corner or an edge without overlapping.
///
/// The widgets of this package, such as `MapCompass`, `MapControlButtons`,
/// `MapScalebar` and `SourceAttribution`, leave out their own `alignment`
/// and `padding` inside a [MapAlign], which places them instead.
///
/// ```dart
/// MapLibreMap(
///   children: const [
///     MapAlign(
///       alignment: Alignment.topRight,
///       children: [MapCompass(), MapControlButtons()],
///     ),
///     MapAlign(
///       alignment: Alignment.bottomLeft,
///       children: [MapScalebar()],
///     ),
///   ],
/// )
/// ```
///
/// Widgets of plugins can do the same with [MapAlign.maybeOf]. Each child
/// gets its own size. Wrap a child that expands, such as an [Align], in a
/// [Flexible], so that it takes the space that the others leave.
///
/// {@category UI}
class MapAlign extends StatelessWidget {
  /// Stacks [children] at [alignment].
  const MapAlign({
    required this.alignment,
    required this.children,
    this.direction = Axis.vertical,
    this.spacing = 8,
    this.padding = const EdgeInsets.all(10),
    super.key,
  });

  /// Where the widgets go on the map.
  final Alignment alignment;

  /// The widgets, from the top or from the left.
  final List<Widget> children;

  /// Whether the widgets are stacked from top to bottom, the default, or
  /// placed side by side.
  final Axis direction;

  /// The space between two widgets, in logical pixels.
  final double spacing;

  /// The space between the widgets and the edges of the map, inside the
  /// safe area of the screen.
  final EdgeInsets padding;

  /// The [alignment] of the closest [MapAlign] around [context], or null if
  /// there is none. A widget that places itself on the map only does so
  /// while this is null.
  static Alignment? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MapAlignScope>()?.alignment;

  @override
  Widget build(BuildContext context) {
    final across = switch (direction) {
      Axis.vertical => alignment.x,
      Axis.horizontal => alignment.y,
    };
    return SafeArea(
      child: Padding(
        padding: padding,
        child: Align(
          alignment: alignment,
          child: _MapAlignScope(
            alignment: alignment,
            child: Flex(
              direction: direction,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: across < 0
                  ? CrossAxisAlignment.start
                  : across > 0
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
              spacing: spacing,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapAlignScope extends InheritedWidget {
  const _MapAlignScope({required this.alignment, required super.child});

  final Alignment alignment;

  @override
  bool updateShouldNotify(_MapAlignScope oldWidget) =>
      alignment != oldWidget.alignment;
}

/// Places [child], a widget of this package, at [alignment] with [padding]
/// inside the safe area, or leaves that to the [MapAlign] around it.
Widget placeOnMap(
  BuildContext context, {
  required Alignment alignment,
  required EdgeInsets padding,
  required Widget child,
  bool safeArea = true,
}) {
  if (MapAlign.maybeOf(context) != null) return child;
  final placed = Container(
    alignment: alignment,
    padding: padding,
    child: child,
  );
  // The SafeArea keeps the widget visible on screens with rounded corners.
  return safeArea ? SafeArea(child: placed) : placed;
}
