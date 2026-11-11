import 'dart:convert';

/// Ajuste con el orden de los programas que el usuario eligió en cada canal
/// de YouTube: un JSON `{ "<clave del canal>": ["<clave del programa>", …] }`.
const youtubeShowOrderSettingKey = 'tvYoutubeShowOrder';

Map<String, List<String>> _decode(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final Object? data;
  try {
    data = jsonDecode(raw);
  } on FormatException {
    return {};
  }
  if (data is! Map) return {};
  final out = <String, List<String>>{};
  data.forEach((channel, order) {
    if (channel is String && order is List) {
      out[channel] = [
        for (final key in order)
          if (key is String) key
      ];
    }
  });
  return out;
}

/// Orden guardado del canal [channelKey] dentro del ajuste [raw]; vacío si no
/// hay o si [raw] no se entiende.
List<String> decodeYoutubeShowOrder(String? raw, String channelKey) =>
    _decode(raw)[channelKey] ?? const [];

/// Valor del ajuste tras fijar [order] para [channelKey], conservando lo de
/// los demás canales (si [raw] no se entiende, se parte de cero).
String encodeYoutubeShowOrder(
        String? raw, String channelKey, List<String> order) =>
    jsonEncode(_decode(raw)..[channelKey] = order);
