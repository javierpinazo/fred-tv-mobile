import 'package:open_tv/backend/m3u.dart' show HttpStatusException;

/// Mensaje en español para un error al agregar una fuente.
String tvAddSourceErrorMessage(Object error) {
  if (error is StateError && error.message == 'duplicate') {
    return 'Ya existe una lista con ese nombre';
  }
  if (error is HttpStatusException) return 'Esta lista no está disponible';
  return 'No se pudo agregar la lista';
}
