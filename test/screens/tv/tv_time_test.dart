import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/l10n/gen/app_localizations_es.dart';
import 'package:open_tv/screens/tv/tv_time.dart';

void main() {
  test('formatAgo', () {
    final l10n = AppLocalizationsEs();
    expect(formatAgo(const Duration(seconds: 30), l10n), 'hace un momento');
    expect(formatAgo(const Duration(minutes: 5), l10n), 'hace 5 min');
    expect(formatAgo(const Duration(hours: 3, minutes: 59), l10n), 'hace 3 h');
    expect(formatAgo(const Duration(days: 2), l10n), 'hace 2 d');
  });
}
