import 'package:open_tv/l10n/l10n.dart';

/// Antigüedad de un programa en el idioma de la app («hace 16 h»).
String youtubeAgeLabel(AppLocalizations l10n, Duration age) {
  final days = age.inDays;
  if (age.inHours < 1) {
    return l10n.ytAgeMinutes(age.inMinutes < 1 ? 1 : age.inMinutes);
  }
  if (days < 1) return l10n.ytAgeHours(age.inHours);
  if (days < 7) return l10n.ytAgeDays(days);
  if (days < 30) return l10n.ytAgeWeeks(days ~/ 7);
  if (days < 365) return l10n.ytAgeMonths(days ~/ 30);
  return l10n.ytAgeYears(days ~/ 365);
}
