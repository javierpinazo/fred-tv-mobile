import 'package:open_tv/backend/m3u.dart' show HttpStatusException;
import 'package:open_tv/l10n/l10n.dart';

/// Mensaje, en el idioma de [l10n], para un error al agregar una fuente.
String tvAddSourceErrorMessage(Object error, AppLocalizations l10n) {
  if (error is StateError && error.message == 'duplicate') {
    return l10n.playlistDuplicate;
  }
  if (error is HttpStatusException) return l10n.sourceErrUnavailable;
  return l10n.sourceErrGeneric;
}
