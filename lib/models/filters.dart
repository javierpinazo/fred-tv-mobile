import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';

class Filters {
  String? query;
  List<int>? sourceIds;
  List<MediaType>? mediaTypes;
  ViewType viewType;
  int page;
  int? seriesId;
  int? groupId;
  String? groupName;
  bool useKeywords;

  /// Oculta los canales marcados como caídos.
  bool hideDead;

  /// Solo canales de este país (código en minúsculas).
  String? country;

  Filters({
    this.query,
    this.sourceIds,
    this.mediaTypes,
    required this.viewType,
    this.page = 1,
    this.seriesId,
    this.groupId,
    this.groupName,
    this.useKeywords = false,
    this.hideDead = false,
    this.country,
  });
}
