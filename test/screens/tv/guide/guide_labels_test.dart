import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/l10n/gen/app_localizations.dart';
import 'package:open_tv/screens/tv/guide/guide_labels.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';

final _start = DateTime.utc(2026, 10, 19, 18);

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  final movie = GuideProgram(
    start: _start,
    end: _start.add(const Duration(minutes: 111)),
    title: 'Wasabi',
    kind: GuideProgramKind.movie,
    year: 2001,
    genre: 'Action & Adventure',
    rating: 'R',
  );
  final series = GuideProgram(
    start: _start,
    end: _start.add(const Duration(minutes: 30)),
    title: 'Las Rutas de Veronica',
    kind: GuideProgramKind.series,
    season: 2,
    episode: 13,
    episodeTitle: 'Comarca Vaqueira',
    year: 2018,
    genre: 'Food & Cooking',
    rating: 'TV-G',
  );
  final plain = GuideProgram(start: _start, title: 'Noticias');

  group('guideMetaLine', () {
    test('película: tipo, año, género, clasificación y duración', () {
      expect(guideMetaLine(movie, es),
          'Película · 2001 · Action & Adventure · R · 111 min');
    });

    test('serie: temporada y capítulo en vez del año', () {
      expect(guideMetaLine(series, es),
          'Serie · T2 E13 · Food & Cooking · TV-G · 30 min');
      expect(guideMetaLine(series, en),
          'Series · S2 E13 · Food & Cooking · TV-G · 30 min');
    });

    test('serie sin temporada: solo el capítulo', () {
      final p = GuideProgram(
          start: _start,
          title: 'Serie',
          kind: GuideProgramKind.series,
          episode: 5);
      expect(guideMetaLine(p, es), 'Serie · Cap. 5');
    });

    test('un programa sin datos extra no tiene línea (ni su duración sola)', () {
      expect(guideMetaLine(plain, es), isNull);
      final timed = GuideProgram(
          start: _start,
          end: _start.add(const Duration(hours: 1)),
          title: 'Noticias');
      expect(guideMetaLine(timed, es), isNull);
    });
  });

  group('guideShortMeta', () {
    test('resume lo esencial para la barra del reproductor', () {
      expect(guideShortMeta(movie, es), 'Película · 2001');
      expect(guideShortMeta(series, es), 'T2 E13');
      expect(guideShortMeta(plain, es), isNull);
    });
  });
}
