import 'package:open_tv/backend/youtube/youtube_program.dart';

/// Un programa conocido de un canal (La Encerrona, Sin Guion…), todavía sin
/// sus emisiones.
class YoutubeShowDef {
  const YoutubeShowDef({
    required this.key,
    required this.name,
    this.playlistIds = const [],
  });

  /// Identifica al programa dentro de su canal: nombre normalizado.
  final String key;
  final String name;

  /// Listas del canal que reúnen sus emisiones (puede no haber ninguna).
  final List<String> playlistIds;
}

/// Un programa con sus emisiones, ya ordenadas para mostrar.
class YoutubeShow {
  const YoutubeShow({
    required this.key,
    required this.name,
    required this.programs,
  });

  final String key;
  final String name;
  final List<YoutubeProgram> programs;
}

enum YoutubeShowMove { first, up, down }

/// Un programa cuya última emisión es más antigua no ocupa fila por sí solo.
const youtubeShowRecent = Duration(days: 30);

/// Las claves más cortas aparecerían dentro de cualquier palabra («yo»,
/// «ppk»): no sirven para reconocer un programa por el título.
const _minTitleKey = 5;

const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

final _alnum = RegExp(r'[a-z0-9]');
final _nameSuffix = RegExp(r'\s+(en vivo|podcast)$', caseSensitive: false);

/// Programas de canales que no publican una lista por programa.
const _builtInShows = <String, List<String>>{
  '/channel/UC-B7Xv56uNRDkj0vC3QW8Cg': [
    'Sin Guion',
    'Fuerte y Claro',
    'Que No Se Te Olvide',
    'La Verdad a Fondo',
    'Arde Troya',
  ],
};

/// Nombres presentables para listas cuyo título no lo es («#LaEncerrona»).
const _fixedNames = <String, String>{'laencerrona': 'La Encerrona'};

const _defaultShow = <String, String>{
  '/channel/UCP0AJJeNkFBYzegTTVbKhPg': 'laencerrona',
  '/channel/UC-B7Xv56uNRDkj0vC3QW8Cg': 'singuion',
  '/channel/UCIpXj6C68YhT8Px3DGCafYA': 'lacontra',
};

/// Minúsculas, sin tildes y solo letras y dígitos: «#LaEncerrona» y «La
/// Encerrona» quedan iguales.
String normalizeYoutubeText(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final plain = _accents[ch] ?? ch;
    if (_alnum.hasMatch(plain)) out.write(plain);
  }
  return out.toString();
}

/// Clave del programa de una lista titulada [title]. «La Contra EN VIVO» y
/// «La Contra Podcast» son el mismo programa.
String youtubeShowKey(String title) {
  final key = normalizeYoutubeText(title);
  for (final suffix in const ['envivo', 'podcast']) {
    if (key.length > suffix.length && key.endsWith(suffix)) {
      return key.substring(0, key.length - suffix.length);
    }
  }
  return key;
}

/// Nombre para mostrar de las listas [titles] de un mismo programa. El final
/// « EN VIVO» / « Podcast» solo se quita cuando hay varias listas: ahí es lo
/// que las distingue («La Contra EN VIVO» + «La Contra Podcast»), mientras
/// que en una sola puede ser parte del nombre («Transmisiones en vivo»).
String _displayName(List<String> titles) {
  String clean(String title) {
    var name = title.trim();
    while (name.startsWith('#')) {
      name = name.substring(1).trim();
    }
    return name;
  }

  if (titles.length == 1) return clean(titles.single);
  String? best;
  for (final title in titles) {
    final name = clean(title);
    final cut = name.replaceFirst(_nameSuffix, '').trim();
    final candidate = cut.isEmpty ? name : cut;
    if (best == null || candidate.length < best.length) best = candidate;
  }
  return best!;
}

/// Programas conocidos del canal [channelKey] (`/channel/UC…` o `/@handle`):
/// sus listas, agrupadas por clave y en el orden de [playlists], y después
/// los programas incorporados que no tengan lista.
List<YoutubeShowDef> youtubeShowDefs(
    String channelKey, List<({String id, String title})> playlists) {
  final titles = <String, List<String>>{};
  final ids = <String, List<String>>{};
  for (final playlist in playlists) {
    final key = youtubeShowKey(playlist.title);
    if (key.isEmpty) continue;
    titles.putIfAbsent(key, () => []).add(playlist.title);
    ids.putIfAbsent(key, () => []).add(playlist.id);
  }
  final names = {for (final e in titles.entries) e.key: _displayName(e.value)};
  for (final name in _builtInShows[channelKey] ?? const <String>[]) {
    final key = youtubeShowKey(name);
    names[key] = name;
    ids.putIfAbsent(key, () => []);
  }
  return [
    for (final key in ids.keys)
      YoutubeShowDef(
        key: key,
        name: _fixedNames[key] ?? names[key]!,
        playlistIds: List.unmodifiable(ids[key]!),
      ),
  ];
}

/// Clave del programa que va arriba mientras el usuario no ordene, o `null`.
String? defaultYoutubeShowKey(String channelKey) => _defaultShow[channelKey];

/// Programa al que apunta el título de una emisión: la clave más larga (de
/// las que sirven para esto) contenida en el título, o `null`.
String? youtubeShowKeyForTitle(String title, Iterable<String> keys) {
  final text = normalizeYoutubeText(title);
  String? best;
  for (final key in keys) {
    if (key.length < _minTitleKey || !text.contains(key)) continue;
    if (best == null || key.length > best.length) best = key;
  }
  return best;
}

/// Antigüedad de la emisión más reciente de [show] (un directo en curso es
/// «ahora»); `null` si no se conoce ninguna.
Duration? youtubeShowRecency(YoutubeShow show) {
  Duration? best;
  for (final p in show.programs) {
    final age = p.isLive ? Duration.zero : p.age;
    if (age != null && (best == null || age < best)) best = age;
  }
  return best;
}

/// Filas de programa a mostrar, en orden: primero los de [order] (lo que el
/// usuario dejó, o el prioritario inicial) y después los demás con alguna
/// emisión reciente, del más reciente al más antiguo. Sin programas vacíos y
/// como mucho [max].
List<YoutubeShow> arrangeYoutubeShows(
  List<YoutubeShow> shows, {
  List<String> order = const [],
  int max = 5,
}) {
  final byKey = {
    for (final s in shows)
      if (s.programs.isNotEmpty) s.key: s
  };
  final out = <YoutubeShow>[];
  for (final key in order) {
    final show = byKey.remove(key);
    if (show != null) out.add(show);
  }
  final rest = <({YoutubeShow show, Duration recency})>[];
  for (final show in byKey.values) {
    final recency = youtubeShowRecency(show);
    if (recency != null && recency < youtubeShowRecent) {
      rest.add((show: show, recency: recency));
    }
  }
  rest.sort((a, b) {
    final byRecency = a.recency.compareTo(b.recency);
    return byRecency != 0 ? byRecency : a.show.name.compareTo(b.show.name);
  });
  out.addAll(rest.map((r) => r.show));
  return out.length > max ? out.sublist(0, max) : out;
}

/// Orden de [visibleKeys] tras mover [key]; el mismo si no se puede mover.
List<String> moveYoutubeShow(
    List<String> visibleKeys, String key, YoutubeShowMove move) {
  final from = visibleKeys.indexOf(key);
  if (from < 0) return visibleKeys;
  final to = switch (move) {
    YoutubeShowMove.first => 0,
    YoutubeShowMove.up => from - 1,
    YoutubeShowMove.down => from + 1,
  };
  if (to < 0 || to >= visibleKeys.length || to == from) return visibleKeys;
  return [...visibleKeys]
    ..removeAt(from)
    ..insert(to, key);
}
