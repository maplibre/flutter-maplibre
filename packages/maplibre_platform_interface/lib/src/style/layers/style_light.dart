part of 'style_layer.dart';

/// What [StyleLight] keeps: the light JSON of the style, and the map it
/// sends changes to. The typed properties are generated from the style spec.
abstract class _StyleLightBase {
  _StyleLightBase(this._backend);

  final StyleBackend _backend;

  /// The light JSON of the style, with the changes made since it loaded.
  final _json = <String, Object?>{};

  var _replaced = false;
  var _warnedReplaced = false;

  /// Reads the light from the `light` member of the style JSON. Platforms
  /// call it when the style loads.
  void load(Object? light) {
    _json.clear();
    if (light is Map<String, Object?>) _json.addAll(light);
  }

  /// Detaches the light, when a new style is set on the map. Platforms call
  /// it. Its setters then only change the object.
  void markReplaced() => _replaced = true;

  /// The light as the light JSON of a style.
  Map<String, Object?> toJson() => {..._json};

  Expression<T> _property<T>(
    String name,
    LiteralDecoder<T> decode,
    Expression<T> fallback,
  ) => switch (_json[name]) {
    null => fallback,
    final json => decodeExpression(json, decode),
  };

  void _setExpression(String name, Expression<Object?>? value) =>
      _write(name, value == null ? null : encodeProperty(value));

  StyleTransition? _transition(String name) =>
      switch (_json['$name-transition']) {
        final Map<String, Object?> json => StyleTransition.fromJson(json),
        _ => null,
      };

  void _setTransition(String name, StyleTransition? value) =>
      _write('$name-transition', value?.toJson());

  void _write(String name, Object? value) {
    if (value == null) {
      _json.remove(name);
    } else {
      _json[name] = value;
    }
    if (_replaced) {
      if (!_warnedReplaced && kDebugMode) {
        debugPrint(
          'maplibre: the style was replaced, so changing its light no '
          'longer updates the map.',
        );
      }
      _warnedReplaced = true;
      return;
    }
    // Both platforms take the whole light best: gl-js only has setLight.
    _backend.setLight(toJson());
  }
}
