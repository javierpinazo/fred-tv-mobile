import 'package:open_tv/l10n/l10n.dart';

/// Tiempo relativo para la UI de TV, en el idioma de [l10n].
String formatAgo(Duration d, AppLocalizations l10n) {
  if (d.inMinutes < 1) return l10n.agoMoment;
  if (d.inHours < 1) return l10n.agoMinutes(d.inMinutes);
  if (d.inDays < 1) return l10n.agoHours(d.inHours);
  return l10n.agoDays(d.inDays);
}
