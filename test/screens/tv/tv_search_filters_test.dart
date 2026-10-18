import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/screens/tv/tv_search_filters.dart';

void main() {
  test('incluye mediaTypes (regresión H1)', () {
    final f = buildTvSearchFilters('  canal   24 ', [1, 2])!;
    expect(f.mediaTypes, [MediaType.livestream, MediaType.movie]);
    expect(f.query, 'canal 24');
    expect(f.useKeywords, isTrue);
    expect(f.viewType, ViewType.all);
    expect(f.sourceIds, [1, 2]);
  });

  test('null con menos de 2 letras',
      () => expect(buildTvSearchFilters(' a ', [1]), isNull));

  test('null sin fuentes', () => expect(buildTvSearchFilters('abc', []), isNull));
}
