import 'dart:convert';

import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

/// Primer valor de un campo de Archive, que puede ser texto, número o lista.
String _first(Object? v) {
  if (v is List) return v.isEmpty ? '' : _first(v.first);
  if (v == null) return '';
  return v.toString().trim();
}

String _allText(Object? v) =>
    v is List ? v.map(_allText).join(' ') : (v?.toString() ?? '');

const _entities = {
  '&amp;': '&',
  '&quot;': '"',
  '&#039;': "'",
  '&#39;': "'",
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': ' ',
};

/// Texto plano de una descripción de Archive (lleva HTML), de hasta 400
/// caracteres.
String _plain(String html) {
  var t = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  _entities.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > 400 ? '${t.substring(0, 400).trimRight()}…' : t;
}

const _letters = r'[a-z0-9áéíóúüñ]';
const _adultWords = r'xxx|porno?|erotic[ao]s?|erótic[ao]s?|erotica|'
    r'sexploitation|nsfw|hardcore|explotaci[oó]n sexual|'
    r'sex|sexo|sexy|sexual(es)?|sexuellement|nudes?|desnud[oa]s?|naked|'
    r'striptease|'
    r'adults? (films?|movies?|only|content|entertainment)|'
    r'(films?|movies?) for adults';
const _adultAge = r'(?<!\d)(18\+|\+18)';

/// Palabras completas (sin letras pegadas por ningún lado) o «18+».
final _adult =
    RegExp('(?<!$_letters)($_adultWords)(?!$_letters)|$_adultAge');

/// `true` si el texto parece de contenido para adultos. Filtro de mínimos por
/// palabras: Internet Archive no está moderado y no trae clasificación.
bool isAdultText(String text) => _adult.hasMatch(text.toLowerCase());

/// Década de [year] («1960s»), o «Sin fecha» si falta o es absurdo.
String archiveDecade(int? year) {
  if (year == null || year < 1890 || year > 2099) return 'Sin fecha';
  return '${year ~/ 10 * 10}s';
}

/// Películas de la búsqueda de Internet Archive (`advancedsearch.php`
/// con `output=json`). Descarta las de adultos. Lanza
/// [OnDemandUnavailableException] si el JSON no tiene la forma esperada o no
/// queda ninguna película.
List<OnDemandTitle> parseArchiveSearch(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw OnDemandUnavailableException(
        'Internet Archive devolvió una respuesta ilegible.');
  }
  final response = decoded is Map ? decoded['response'] : null;
  final docs = response is Map ? response['docs'] : null;
  if (docs is! List) {
    throw OnDemandUnavailableException('Internet Archive cambió su búsqueda.');
  }
  final out = <OnDemandTitle>[];
  for (final d in docs) {
    if (d is! Map) continue;
    final id = _first(d['identifier']);
    final title = _plain(_first(d['title']));
    if (id.isEmpty || title.isEmpty) continue;
    final description = _first(d['description']);
    if (isAdultText('$title ${_allText(d['description'])} ${_allText(d['subject'])}')) {
      continue;
    }
    final year = int.tryParse(_first(d['year']));
    final decade = archiveDecade(year);
    out.add(OnDemandTitle(
      id: id,
      title: title,
      synopsis: _plain(description),
      posterUrl: 'https://archive.org/services/img/$id',
      details: decade == 'Sin fecha' ? '' : '$year',
      source: ArchiveSource(id),
      categories: [decade],
    ));
  }
  if (out.isEmpty) {
    throw OnDemandUnavailableException('Internet Archive no trae películas.');
  }
  return out;
}
