import 'package:flutter/foundation.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/youtube/youtube_channel_service.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';

/// Canales de YouTube con películas completas subidas por quien tiene los
/// derechos. Solo entran los que el usuario confirma: la app no busca
/// películas por su cuenta.
///
/// `captions` pide subtítulos al reproductor: se activa en los canales cuyas
/// películas no están en español.
const List<({String name, String url, bool captions})>
    defaultYoutubeMovieChannels = [
  (name: 'Butaca', url: 'https://www.youtube.com/@butaca', captions: false),
  (
    name: 'Cinefilia',
    url: 'https://www.youtube.com/@Cinefiliablog',
    captions: true
  ),
  (
    name: 'PizzaFlix',
    url: 'https://www.youtube.com/@PizzaFLIX',
    captions: true
  ),
  (
    name: 'CINETEL',
    url: 'https://www.youtube.com/@CINETELMULTIMEDIA',
    captions: false
  ),
  (
    name: 'Mosfilm',
    url: 'https://www.youtube.com/@Mosfilm_eng',
    captions: true
  ),
];

/// Una película dura al menos una hora; lo demás (cortos, avances, capítulos)
/// no se ofrece.
const _minMovieSeconds = 60 * 60;

int? _seconds(String? duration) {
  if (duration == null) return null;
  final parts = duration.trim().split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final nums = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    nums.add(n);
  }
  return nums.length == 3
      ? nums[0] * 3600 + nums[1] * 60 + nums[2]
      : nums[0] * 60 + nums[1];
}

/// Minutos (redondeados) de una duración de YouTube «1:21:49» o «58:01»;
/// `null` si no lo es («EN VIVO», vacío…).
int? youtubeDurationMinutes(String? duration) {
  final s = _seconds(duration);
  return s == null ? null : (s / 60).round();
}

// « - Película Completa», « | Película Completa Restaurada en HD»,
// « - Películas Clásicas Completas»… siempre tras un separador.
final _movieSuffix = RegExp(
    r'\s*[-–|]\s*pel[ií]culas?\s+(cl[aá]sicas?\s+)?completas?\b.*$',
    caseSensitive: false);

final _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
    unicode: true);

final _titleTail = RegExp(
    r'\s*(full\s*hd\s*movie|pel[ií]cula en espa[ñn]ol)\s*$',
    caseSensitive: false);

/// Título para mostrar: sin emojis ni los «| Película en Español», «Full HD
/// Movie»… que los canales añaden. Si no queda nada útil, el original.
String _cleanTitle(String title) {
  var t = title.split('|').first;
  t = t.replaceFirst(_movieSuffix, '');
  t = t.replaceAll(_emoji, '');
  t = t.replaceFirst(_titleTail, '').trim();
  return t.length >= 2 ? t : title.trim();
}

/// Películas completas de canales concretos de YouTube. Se reproducen con el
/// reproductor de YouTube que ya tiene la app.
class YoutubeMoviesProvider implements OnDemandProvider {
  YoutubeMoviesProvider({
    YoutubeChannelService? service,
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 30),
    this.channels = defaultYoutubeMovieChannels,
  })  : _service = service ?? YoutubeChannelService(),
        _now = now ?? DateTime.now;

  final YoutubeChannelService _service;
  final DateTime Function() _now;
  final Duration ttl;
  final List<({String name, String url, bool captions})> channels;

  List<OnDemandTitle>? _cache;
  DateTime? _cachedAt;

  @override
  String get id => 'youtube-movies';

  @override
  String get name => 'YouTube';

  @override
  Future<List<OnDemandTitle>> titles() async {
    final cached = _cache;
    final at = _cachedAt;
    if (cached != null && at != null && _now().difference(at) < ttl) {
      return cached;
    }
    final byId = <String, YoutubeProgram>{};
    final cats = <String, List<String>>{};
    final channelOf = <String, ({String name, bool captions})>{};
    var anyChannelRead = false;
    for (final c in channels) {
      final List<YoutubeProgram> programs;
      try {
        programs = await _service.programs(c.url);
      } on YoutubeUnavailableException catch (e) {
        debugPrint('YoutubeMoviesProvider: canal «${c.name}» omitido: $e');
        continue;
      }
      anyChannelRead = true;
      for (final p in programs) {
        final secs = _seconds(p.duration);
        if (p.kind != YoutubeProgramKind.video ||
            secs == null ||
            secs < _minMovieSeconds) {
          continue;
        }
        byId.putIfAbsent(p.videoId, () => p);
        channelOf.putIfAbsent(
            p.videoId, () => (name: c.name, captions: c.captions));
        final list = cats.putIfAbsent(p.videoId, () => []);
        if (!list.contains(c.name)) list.add(c.name);
      }
    }
    if (!anyChannelRead) {
      throw OnDemandUnavailableException(
          'No se pudo leer ningún canal de YouTube.');
    }
    if (byId.isEmpty) {
      throw OnDemandUnavailableException(
          'Los canales de YouTube no traen películas.');
    }
    final titles = [
      for (final e in byId.entries)
        OnDemandTitle(
          id: e.key,
          title: _cleanTitle(e.value.title),
          synopsis: '',
          posterUrl: e.value.thumbnail,
          details: '${youtubeDurationMinutes(e.value.duration)} min. · '
              '${channelOf[e.key]!.name}',
          source: YoutubeSource(e.key, captions: channelOf[e.key]!.captions),
          categories: cats[e.key]!,
        ),
    ];
    _cache = titles;
    _cachedAt = _now();
    return titles;
  }
}
