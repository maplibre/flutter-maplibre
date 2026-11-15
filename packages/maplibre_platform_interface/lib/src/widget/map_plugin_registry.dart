import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// A mounted [MapPlugin], as the map sees it.
abstract interface class MapPluginEntry {
  /// The current widget of the plugin.
  MapPlugin get plugin;
}

/// The [MapPlugin]s below a map. The map combines what they declare with
/// its own parameters.
class MapPluginRegistry {
  /// Creates a registry that calls [onChanged] after the frame in which
  /// plugins were added, removed or rebuilt.
  MapPluginRegistry(this.onChanged);

  /// Called once after a frame in which the plugins changed.
  final VoidCallback onChanged;

  final _entries = <MapPluginEntry>{};

  /// The registered plugins, in no particular order.
  Set<MapPluginEntry> get entries => _entries;

  var _scheduled = false;
  var _disposed = false;

  /// Adds [entry], which was just mounted.
  void add(MapPluginEntry entry) {
    _entries.add(entry);
    _changed();
  }

  /// Notes that the widget of [entry] changed.
  void update(MapPluginEntry entry) => _changed();

  /// Removes [entry], which is about to be unmounted.
  void remove(MapPluginEntry entry) {
    if (_entries.remove(entry)) _changed();
  }

  /// Stops reporting changes, as the map is gone.
  void dispose() => _disposed = true;

  void _changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    // Plugins change while the tree builds, where the map must not rebuild.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _scheduled = false;
        if (!_disposed) onChanged();
      })
      ..ensureVisualUpdate();
  }
}

/// The render object of a [MapPlugin]. It fills the map, lays its child out
/// like a child of the map, and takes part in hit tests without taking the
/// hit, so that the map finds the plugins under a pointer in the order that
/// Flutter hit-tests them: the topmost first, inner before outer.
class RenderMapPlugin extends RenderProxyBox {
  /// Creates the render object of [entry].
  RenderMapPlugin(this.entry);

  /// The plugin that this render object belongs to.
  MapPluginEntry entry;

  @override
  void performLayout() {
    final child = this.child;
    final constraints = this.constraints;
    child?.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.hasBoundedWidth && constraints.hasBoundedHeight
        ? constraints.biggest
        : constraints.constrain(child?.size ?? Size.zero);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final hit = hitTestChildren(result, position: position);
    // Takes part, but leaves the hit to the child, so the map below still
    // gets the pointer.
    result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}

/// Builds a [RenderMapPlugin].
class MapPluginRenderWidget extends SingleChildRenderObjectWidget {
  /// Creates the render widget of [entry].
  const MapPluginRenderWidget({required this.entry, super.child, super.key});

  /// The plugin.
  final MapPluginEntry entry;

  @override
  RenderMapPlugin createRenderObject(BuildContext context) =>
      RenderMapPlugin(entry);

  @override
  void updateRenderObject(BuildContext context, RenderMapPlugin renderObject) {
    renderObject.entry = entry;
  }
}
