/// Tiempo relativo en español para la UI de TV.
String formatAgo(Duration d) {
  if (d.inMinutes < 1) return 'hace un momento';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}
