import 'package:open_tv/l10n/gen/app_localizations.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';

String? _kindLabel(GuideProgram p, AppLocalizations l10n) => switch (p.kind) {
      GuideProgramKind.movie => l10n.guideKindMovie,
      GuideProgramKind.series => l10n.guideKindSeries,
      null => null,
    };

/// `T2 E13`, `Cap. 13` o `null`.
String? _episodeLabel(GuideProgram p, AppLocalizations l10n) {
  if (p.episode == null) return null;
  return p.season == null
      ? l10n.guideEpisode('${p.episode}')
      : l10n.guideSeasonEpisode('${p.season}', '${p.episode}');
}

/// `Serie · T2 E13 · Comedia · TV-G · 30 min` o `Película · 2001 · Acción · R ·
/// 111 min`; `null` si la fuente solo dio hora y título.
String? guideMetaLine(GuideProgram p, AppLocalizations l10n) {
  final episode = _episodeLabel(p, l10n);
  final parts = [
    _kindLabel(p, l10n),
    // En las series el año de estreno dice poco al lado del capítulo.
    if (episode != null) episode else if (p.year != null) '${p.year}',
    p.genre,
    p.rating,
  ].whereType<String>().toList();
  if (parts.isEmpty) return null;
  final minutes = p.duration?.inMinutes ?? 0;
  if (minutes > 0) parts.add('$minutes min');
  return parts.join(' · ');
}

/// Lo esencial para una sola línea: `T2 E13` o `Película · 2001`.
String? guideShortMeta(GuideProgram p, AppLocalizations l10n) {
  final episode = _episodeLabel(p, l10n);
  if (episode != null) return episode;
  final parts = [
    _kindLabel(p, l10n),
    if (p.year != null) '${p.year}',
  ].whereType<String>();
  return parts.isEmpty ? null : parts.join(' · ');
}
