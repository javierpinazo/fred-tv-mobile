import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/youtube/youtube_age_label.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('elige la unidad según la antigüedad', () {
    expect(youtubeAgeLabel(es, const Duration(seconds: 30)), 'hace 1 min');
    expect(youtubeAgeLabel(es, const Duration(minutes: 59)), 'hace 59 min');
    expect(youtubeAgeLabel(es, const Duration(hours: 1)), 'hace 1 h');
    expect(youtubeAgeLabel(es, const Duration(hours: 16)), 'hace 16 h');
    expect(youtubeAgeLabel(es, const Duration(days: 1)), 'hace 1 día');
    expect(youtubeAgeLabel(es, const Duration(days: 4)), 'hace 4 días');
    expect(youtubeAgeLabel(es, const Duration(days: 7)), 'hace 1 semana');
    expect(youtubeAgeLabel(es, const Duration(days: 21)), 'hace 3 semanas');
    expect(youtubeAgeLabel(es, const Duration(days: 30)), 'hace 1 mes');
    expect(youtubeAgeLabel(es, const Duration(days: 60)), 'hace 2 meses');
    expect(youtubeAgeLabel(es, const Duration(days: 365)), 'hace 1 año');
    expect(youtubeAgeLabel(es, const Duration(days: 800)), 'hace 2 años');
  });

  test('sale en el idioma de la app', () {
    expect(youtubeAgeLabel(en, const Duration(hours: 16)), '16 h ago');
    expect(youtubeAgeLabel(en, const Duration(days: 4)), '4 days ago');
  });
}
