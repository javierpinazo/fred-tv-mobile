import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/tv_time.dart';

void main() {
  test('formatAgo', () {
    expect(formatAgo(const Duration(seconds: 30)), 'hace un momento');
    expect(formatAgo(const Duration(minutes: 5)), 'hace 5 min');
    expect(formatAgo(const Duration(hours: 3, minutes: 59)), 'hace 3 h');
    expect(formatAgo(const Duration(days: 2)), 'hace 2 d');
  });
}
