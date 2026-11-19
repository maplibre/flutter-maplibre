import 'dart:collection';

import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';
import 'package:maplibre_platform_interface/src/style/expressions/expression_json.dart';

/// The global state of a map style, which layers read with the
/// `global-state` expression ([Expression.globalState]).
///
/// It is the `state` defaults of the style, overridden by
/// [MapOptions.globalState]. It is read only: change
/// [MapOptions.globalState] to change it.
///
/// {@category Style}
final class StyleGlobalState extends UnmodifiableMapBase<String, Object?> {
  /// Creates the global state of a style that has not loaded yet. Platforms
  /// create it on their [StyleBackend].
  StyleGlobalState(this._backend);

  final StyleBackend _backend;

  /// The defaults of the style's `state`.
  Map<String, Object?> _defaults = const {};

  /// The values of [MapOptions.globalState] that reached the map, without
  /// nulls.
  Map<String, Object?> _values = const {};

  var _replaced = false;

  @override
  Object? operator [](Object? key) =>
      _values.containsKey(key) ? _values[key] : _defaults[key];

  @override
  Iterable<String> get keys => {..._defaults.keys, ..._values.keys};

  /// Reads the defaults from the `state` member of the style JSON. Platforms
  /// call it when the style loads.
  void load(Object? state) {
    _defaults = {
      if (state is Map<String, Object?>)
        for (final MapEntry(:key, :value) in state.entries)
          if (value is Map<String, Object?>) key: value['default'],
    };
  }

  /// Sends the values of [values] that changed to the map. A key that is
  /// missing or null goes back to the style's default. Platforms call it with
  /// [MapOptions.globalState] once the style loaded and when the options
  /// change.
  void apply(Map<String, Object?> values) {
    if (_replaced) return;
    final next = {
      for (final MapEntry(:key, :value) in values.entries) key: ?value,
    };
    // A key in only one of them was added, or removed and goes back to its
    // default.
    for (final key in {..._values.keys, ...next.keys}) {
      final value = next[key];
      if (_values.containsKey(key) && jsonEquals(_values[key], value)) {
        continue;
      }
      _backend.setGlobalStateProperty(key, value ?? _defaults[key]);
    }
    _values = Map.unmodifiable(next);
  }

  /// Detaches the state, when a new style is set on the map. Platforms call
  /// it.
  void markReplaced() => _replaced = true;
}
