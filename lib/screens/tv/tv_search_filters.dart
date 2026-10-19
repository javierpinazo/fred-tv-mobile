import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';

const int tvSearchMinChars = 2;

Filters? buildTvSearchFilters(String rawQuery, List<int> sourceIds,
    {String? country}) {
  final query = rawQuery.trim().replaceAll(RegExp(r'\s+'), ' ');
  // Con un país elegido se puede listar sin escribir nada.
  if ((query.length < tvSearchMinChars && country == null) ||
      sourceIds.isEmpty) {
    return null;
  }
  return Filters(
    viewType: ViewType.all,
    sourceIds: sourceIds,
    query: query,
    useKeywords: true,
    mediaTypes: [MediaType.livestream, MediaType.movie],
    country: country,
  );
}
