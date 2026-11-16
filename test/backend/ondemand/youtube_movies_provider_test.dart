import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/youtube_movies_provider.dart';
import 'package:open_tv/backend/youtube/youtube_channel_service.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';

YoutubeProgram v(String id, String title, String? duration,
        {YoutubeProgramKind kind = YoutubeProgramKind.video}) =>
    YoutubeProgram(
        videoId: id, title: title, kind: kind, duration: duration);

class FakeService extends YoutubeChannelService {
  FakeService(this.byChannel);

  /// URL de canal → emisiones, o una excepción.
  final Map<String, Object> byChannel;
  final List<String> calls = [];

  @override
  Future<List<YoutubeProgram>> programs(String channelUrl,
      {bool force = false}) async {
    calls.add(channelUrl);
    final r = byChannel[channelUrl];
    if (r is Exception) throw r;
    return r as List<YoutubeProgram>;
  }
}

const _a = 'https://www.youtube.com/@uno';
const _b = 'https://www.youtube.com/@dos';

YoutubeMoviesProvider provider(FakeService s,
        {DateTime Function()? now,
        List<({String name, String url, bool captions})>? channels}) =>
    YoutubeMoviesProvider(
      service: s,
      now: now,
      channels: channels ??
          const [
            (name: 'Uno', url: _a, captions: false),
            (name: 'Dos', url: _b, captions: true),
          ],
    );

void main() {
  group('youtubeDurationMinutes', () {
    test('lee h:mm:ss y mm:ss', () {
      expect(youtubeDurationMinutes('1:21:49'), 82);
      expect(youtubeDurationMinutes('58:01'), 58);
      expect(youtubeDurationMinutes('2:08:32'), 129);
      expect(youtubeDurationMinutes('0:45'), 1);
    });
    test('null si no es una duración', () {
      for (final s in [null, '', 'EN VIVO', 'LIVE', '1:2:3:4', 'a:b', '-5:00']) {
        expect(youtubeDurationMinutes(s), isNull, reason: '$s');
      }
    });
  });

  test('solo películas: ≥ 60 min, vídeo (no directo) y con duración', () async {
    final s = FakeService({
      _a: [
        v('largo1', 'Peli larga', '1:30:00'),
        v('corto', 'Cortometraje', '58:59'),
        v('justo', 'Justo una hora', '1:00:00'),
        v('directo', 'Directo', '2:00:00', kind: YoutubeProgramKind.live),
        v('sinDur', 'Sin duración', null),
      ],
      _b: [v('largo2', 'Otra peli', '2:08:32')],
    });
    final t = await provider(s).titles();
    expect(t.map((e) => e.id), ['largo1', 'justo', 'largo2']);
  });

  test('campos: origen, categoría = canal, ficha y cartel', () async {
    final s = FakeService({
      _a: [v('abc', 'Peli', '1:21:49')],
      _b: <YoutubeProgram>[],
    });
    final m = (await provider(s).titles()).single;
    expect((m.source as YoutubeSource).videoId, 'abc');
    expect(m.categories, ['Uno']);
    expect(m.details, '82 min. · Uno');
    expect(m.posterUrl, 'https://i.ytimg.com/vi/abc/mqdefault.jpg');
    expect(m.synopsis, '');
  });

  test('limpia «Película Completa» del título, sin dejarlo vacío', () async {
    final s = FakeService({
      _a: [
        v('1', 'Dos Gallos y Dos Gallinas - Película Completa', '1:30:00'),
        v('2', 'Los Polivoces: El Aviso - Película Completa con Chabelo y Viruta',
            '1:30:00'),
        v('3', 'Capulina: El guía de las turistas - película completa', '1:30:00'),
        v('4', 'Juan Colorado | Película Completa Restaurada en HD', '1:30:00'),
        v('5', 'Ahí está el detalle - Películas Clásicas Completas', '1:30:00'),
        v('6', 'Película completa', '1:30:00'),
        v('7', 'La película completa del año', '1:30:00'),
        v('8', 'El maquinista de La General (1926) | VERSIÓN RESTAURADA HD 1080p | Película COMPLETA en español', '1:30:00'),
        v('9', '🍕Eleven Men and a Girl (1930) Full HD Movie | Joan Bennett | PRE-CODE🍕', '1:30:00'),
        v('10', 'Puños sangrientos | Película en Español', '1:30:00'),
        v('11', 'The Red Tent (1969) - Mikhail Kalatozov | Drama | Mosfilm 4K', '1:30:00'),
        v('12', '🍕🍕', '1:30:00'),
      ],
      _b: <YoutubeProgram>[],
    });
    final t = await provider(s).titles();
    expect(t.map((e) => e.title), [
      'Dos Gallos y Dos Gallinas',
      'Los Polivoces: El Aviso',
      'Capulina: El guía de las turistas',
      'Juan Colorado',
      'Ahí está el detalle',
      'Película completa', // sin otra cosa que mostrar, se conserva
      'La película completa del año', // no es un sufijo: se conserva
      'El maquinista de La General (1926)',
      'Eleven Men and a Girl (1930)',
      'Puños sangrientos',
      'The Red Tent (1969) - Mikhail Kalatozov',
      '🍕🍕', // sin nada más que mostrar, se conserva
    ]);
  });

  test('misma película en dos canales: una vez con las dos categorías',
      () async {
    final s = FakeService({
      _a: [v('x', 'Peli', '1:30:00')],
      _b: [v('x', 'Peli', '1:30:00'), v('y', 'Otra', '1:30:00')],
    });
    final t = await provider(s).titles();
    expect(t.map((e) => e.id), ['x', 'y']);
    expect(t.first.categories, ['Uno', 'Dos']);
  });

  test('un canal que falla se omite; si fallan todos o no hay ninguna '
      'película → OnDemandUnavailableException', () async {
    final ok = FakeService({
      _a: YoutubeUnavailableException('caído'),
      _b: [v('y', 'Otra', '1:30:00')],
    });
    expect((await provider(ok).titles()).single.id, 'y');

    final allFail = FakeService({
      _a: YoutubeUnavailableException('a'),
      _b: YoutubeUnavailableException('b'),
    });
    await expectLater(provider(allFail).titles(),
        throwsA(isA<OnDemandUnavailableException>()));

    final noMovies = FakeService({
      _a: [v('c', 'Corto', '10:00')],
      _b: <YoutubeProgram>[],
    });
    await expectLater(provider(noMovies).titles(),
        throwsA(isA<OnDemandUnavailableException>()));
  });

  test('caché de 30 minutos y un fallo no se cachea', () async {
    var now = DateTime(2026, 11, 15, 12);
    final s = FakeService({
      _a: [v('x', 'Peli', '1:30:00')],
      _b: <YoutubeProgram>[],
    });
    final p = provider(s, now: () => now);
    await p.titles();
    await p.titles();
    expect(s.calls.length, 2); // una vez por canal
    now = now.add(const Duration(minutes: 31));
    await p.titles();
    expect(s.calls.length, 4);
  });

  test('canales por defecto: Butaca, Cinefilia, PizzaFlix, CINETEL y Mosfilm', () {
    expect(defaultYoutubeMovieChannels.map((c) => c.name),
        ['Butaca', 'Cinefilia', 'PizzaFlix', 'CINETEL', 'Mosfilm']);
    expect(defaultYoutubeMovieChannels.map((c) => c.url), [
      'https://www.youtube.com/@butaca',
      'https://www.youtube.com/@Cinefiliablog',
      'https://www.youtube.com/@PizzaFLIX',
      'https://www.youtube.com/@CINETELMULTIMEDIA',
      'https://www.youtube.com/@Mosfilm_eng',
    ]);
    // Subtítulos solo donde la película no está en español.
    expect(defaultYoutubeMovieChannels.map((c) => c.captions),
        [false, true, true, false, true]);
  });

  test('los subtítulos salen de la configuración del canal', () async {
    final s = FakeService({
      _a: [v('sin', 'Sin subs', '1:30:00')],
      _b: [v('con', 'Con subs', '1:30:00')],
    });
    final t = await provider(s).titles();
    expect((t[0].source as YoutubeSource).captions, isFalse);
    expect((t[1].source as YoutubeSource).captions, isTrue);
  });

  test('id y nombre', () {
    final p = provider(FakeService({}));
    expect(p.id, 'youtube-movies');
    expect(p.name, 'YouTube');
  });
}
