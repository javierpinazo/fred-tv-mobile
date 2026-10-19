import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/tv_platform.dart';

/// Enlaces propios (`fredtv://…`) que abren la app desde la pantalla de inicio
/// de Android TV o desde la búsqueda del sistema.
sealed class TvLink {
  const TvLink();
}

/// `fredtv://play?name=…&source=…`: reproduce un canal.
final class TvPlayLink extends TvLink {
  const TvPlayLink(this.name, this.source);
  final String name;
  final String? source;
}

/// `fredtv://search?q=…`: abre Buscar con esa consulta.
final class TvSearchLink extends TvLink {
  const TvSearchLink(this.query);
  final String query;
}

String tvPlayLink(String name, String sourceName) => Uri(
      scheme: 'fredtv',
      host: 'play',
      queryParameters: {'name': name, 'source': sourceName},
    ).toString();

/// `null` si el texto no es un enlace de la app o le faltan datos.
TvLink? parseTvLink(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'fredtv') return null;
  switch (uri.host) {
    case 'play':
      final name = uri.queryParameters['name'];
      if (name == null || name.isEmpty) return null;
      final source = uri.queryParameters['source'];
      return TvPlayLink(name, source == null || source.isEmpty ? null : source);
    case 'search':
      final q = uri.queryParameters['q']?.trim();
      return q == null || q.isEmpty ? null : TvSearchLink(q);
  }
  return null;
}

/// Máximo de elementos de la fila "Favoritos" de la pantalla de inicio.
const int homeRowMaxItems = 20;

/// Favoritos como elementos de la fila de inicio. [sourceNames] traduce el id
/// de fuente a su nombre; los canales de fuentes desconocidas se omiten.
List<TvHomeItem> buildHomeItems(
    List<Channel> channels, Map<int, String> sourceNames) {
  final items = <TvHomeItem>[];
  for (final c in channels) {
    final source = sourceNames[c.sourceId];
    if (source == null) continue;
    items.add(TvHomeItem(
      title: c.name,
      image: c.image == null || c.image!.isEmpty ? null : c.image,
      link: tvPlayLink(c.name, source),
    ));
    if (items.length >= homeRowMaxItems) break;
  }
  return items;
}
