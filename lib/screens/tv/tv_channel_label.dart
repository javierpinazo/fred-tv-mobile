/// Nombre de canal listo para pintar: título limpio y calidad aparte.
class TvChannelLabel {
  const TvChannelLabel(this.title, [this.quality]);

  final String title;

  /// «1080p», «576i»… si el nombre la traía entre paréntesis.
  final String? quality;
}

final RegExp _bracketTags = RegExp(r'\[[^\]]*\]');
final RegExp _qualityTag = RegExp(r'\((\d{3,4}[pi])\)');

/// Separa del nombre las etiquetas entre corchetes («[Not 24/7]») y la calidad
/// («(1080p)»). Solo afecta a lo que se dibuja: el nombre guardado no cambia.
TvChannelLabel tvChannelLabel(String name) {
  final quality = _qualityTag.firstMatch(name)?.group(1);
  final title = name
      .replaceAll(_bracketTags, ' ')
      .replaceAll(_qualityTag, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (title.isEmpty) return TvChannelLabel(name);
  return TvChannelLabel(title, quality);
}
