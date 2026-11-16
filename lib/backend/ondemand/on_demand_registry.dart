import 'package:flutter/material.dart';
import 'package:open_tv/backend/ondemand/archive_vod_provider.dart';
import 'package:open_tv/backend/ondemand/cineaparte_provider.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/plex_vod_provider.dart';
import 'package:open_tv/backend/ondemand/pluto_vod_provider.dart';

/// Servicios conectados a la pantalla de la TV. Quitar uno devuelve su
/// tarjeta a «Próximamente».
const kOnDemandEnabledServices = {'cineaparte', 'pluto', 'plex', 'archive'};

/// Un servicio de películas que lista la pantalla «On demand».
class OnDemandService {
  const OnDemandService({
    required this.id,
    required this.name,
    required this.icon,
    this.provider,
  });

  final String id;
  final String name;
  final IconData icon;

  /// `null` mientras el servicio no esté hecho.
  final OnDemandProvider? provider;

  bool get enabled =>
      provider != null && kOnDemandEnabledServices.contains(id);
}

/// Servicios de la pantalla, en el orden en que se muestran.
List<OnDemandService> onDemandServices() => [
      OnDemandService(
        id: 'cineaparte',
        name: 'Cineaparte',
        icon: Icons.movie_filter_outlined,
        provider: CineaparteProvider(),
      ),
      OnDemandService(
          id: 'pluto',
          name: 'Pluto TV',
          icon: Icons.live_tv_outlined,
          provider: PlutoVodProvider()),
      OnDemandService(
          id: 'plex',
          name: 'Plex',
          icon: Icons.play_circle_outline,
          provider: PlexVodProvider()),
      OnDemandService(
          id: 'archive',
          name: 'Internet Archive',
          icon: Icons.account_balance_outlined,
          provider: ArchiveVodProvider()),
      const OnDemandService(
          id: 'youtube-movies',
          name: 'YouTube',
          icon: Icons.smart_display_outlined),
    ];
