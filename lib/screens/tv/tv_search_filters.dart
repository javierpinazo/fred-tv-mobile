import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';

const int tvSearchMinChars = 2;

Filters? buildTvSearchFilters(String rawQuery, List<int> sourceIds) {
  final query = rawQuery.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (query.length < tvSearchMinChars || sourceIds.isEmpty) return null;
  return Filters(
    viewType: ViewType.all,
    sourceIds: sourceIds,
    query: query,
    useKeywords: true,
    mediaTypes: [MediaType.livestream, MediaType.movie],
  );
}
