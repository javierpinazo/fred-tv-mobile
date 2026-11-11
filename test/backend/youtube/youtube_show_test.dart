import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/backend/youtube/youtube_show.dart';

YoutubeProgram p(String id, {Duration? age, bool live = false}) =>
    YoutubeProgram(
      videoId: id.padRight(11, 'x'),
      title: id,
      kind: live ? YoutubeProgramKind.live : YoutubeProgramKind.video,
      duration: live ? null : '10:00',
      age: age,
    );

YoutubeShow show(String key, List<YoutubeProgram> programs) =>
    YoutubeShow(key: key, name: key, programs: programs);

void main() {
  test('normaliza', () {
    expect(normalizeYoutubeText('¿Qué PASÓ? #LaEncerrona ñ'),
        'quepasolaencerronan');
  });

  test('clave de lista', () {
    expect(youtubeShowKey('#LaEncerrona'), 'laencerrona');
    expect(youtubeShowKey('La Contra EN VIVO'), 'lacontra');
    expect(youtubeShowKey('La Contra Podcast'), 'lacontra');
    expect(youtubeShowKey('Contraataque EN VIVO'), 'contraataque');
    expect(youtubeShowKey('Podcast'), 'podcast');
  });

  test('agrupa listas con la misma clave y fija nombres', () {
    final defs = youtubeShowDefs('/channel/UCIpXj6C68YhT8Px3DGCafYA', [
      (id: 'PLa', title: 'La Contra EN VIVO'),
      (id: 'PLb', title: 'La Contra Podcast'),
      (id: 'PLc', title: 'Helado B'),
    ]);
    expect(defs.map((d) => d.key), ['lacontra', 'heladob']);
    expect(defs.first.name, 'La Contra');
    expect(defs.first.playlistIds, ['PLa', 'PLb']);
    expect(
        youtubeShowDefs('/channel/UCP0AJJeNkFBYzegTTVbKhPg',
            [(id: 'PLx', title: '#LaEncerrona')]).single.name,
        'La Encerrona');
  });

  test('incorporados de La República; listas vacías o raras no rompen', () {
    final defs = youtubeShowDefs('/channel/UC-B7Xv56uNRDkj0vC3QW8Cg', [
      (id: 'PL1', title: ''),
      (id: 'PL2', title: '¡¡!!'),
      (id: 'PL3', title: 'H&H'),
    ]);
    expect(
        defs.map((d) => d.key),
        containsAll([
          'singuion',
          'fuerteyclaro',
          'quenoseteolvide',
          'laverdadafondo',
          'ardetroya',
          'hh',
        ]));
    expect(defs.any((d) => d.key.isEmpty), isFalse);
    expect(defs.firstWhere((d) => d.key == 'singuion').name, 'Sin Guion');
  });

  test('prioritarios iniciales', () {
    expect(defaultYoutubeShowKey('/channel/UCP0AJJeNkFBYzegTTVbKhPg'),
        'laencerrona');
    expect(
        defaultYoutubeShowKey('/channel/UC-B7Xv56uNRDkj0vC3QW8Cg'), 'singuion');
    expect(
        defaultYoutubeShowKey('/channel/UCIpXj6C68YhT8Px3DGCafYA'), 'lacontra');
    expect(defaultYoutubeShowKey('/@otro'), isNull);
  });

  test('pertenencia por título: gana la clave más larga; cortas no cuentan',
      () {
    const keys = ['lacontra', 'lacontraopina', 'hh', 'singuion'];
    expect(youtubeShowKeyForTitle('X | #LaContraOpina 3/11', keys),
        'lacontraopina');
    expect(
        youtubeShowKeyForTitle(
            'KEIKO SE VA | SIN GUION CON ROSA MARÍA PALACIOS', keys),
        'singuion');
    expect(youtubeShowKeyForTitle('ehh hhola', keys), isNull);
  });

  test('orden de filas', () {
    final shows = [
      show('viejo', [p('a', age: const Duration(days: 40))]),
      show('ayer', [p('b', age: const Duration(days: 1))]),
      show('hoy', [p('c', age: const Duration(hours: 2))]),
      show('vivo', [p('d', live: true)]),
      show('vacio', []),
      show('sinedad', [p('e')]),
    ];
    expect(arrangeYoutubeShows(shows).map((s) => s.key),
        ['vivo', 'hoy', 'ayer']);
    expect(
        arrangeYoutubeShows(shows,
            order: ['viejo', 'noexiste', 'vacio', 'ayer']).map((s) => s.key),
        ['viejo', 'ayer', 'vivo', 'hoy']);
    expect(arrangeYoutubeShows(shows, max: 2).length, 2);
  });

  test('mover', () {
    const k = ['a', 'b', 'c'];
    expect(moveYoutubeShow(k, 'c', YoutubeShowMove.first), ['c', 'a', 'b']);
    expect(moveYoutubeShow(k, 'b', YoutubeShowMove.up), ['b', 'a', 'c']);
    expect(moveYoutubeShow(k, 'b', YoutubeShowMove.down), ['a', 'c', 'b']);
    expect(moveYoutubeShow(k, 'a', YoutubeShowMove.up), k);
    expect(moveYoutubeShow(k, 'c', YoutubeShowMove.down), k);
    expect(moveYoutubeShow(k, 'zz', YoutubeShowMove.first), k);
  });
}
