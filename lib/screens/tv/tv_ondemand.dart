import 'package:flutter/material.dart';
import 'package:open_tv/backend/ondemand/on_demand_registry.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Pantalla «On demand»: una tarjeta por servicio de películas. Por ahora
/// ninguna abre nada: los servicios aún no están conectados a la TV.
class TvOnDemandScreen extends StatefulWidget {
  const TvOnDemandScreen({super.key, this.services});

  /// Servicios a mostrar; por defecto los del registro.
  final List<OnDemandService>? services;

  @override
  State<TvOnDemandScreen> createState() => _TvOnDemandScreenState();
}

class _TvOnDemandScreenState extends State<TvOnDemandScreen> {
  late final List<OnDemandService> _services =
      widget.services ?? onDemandServices();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: TvTheme.safeArea,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.navOnDemand,
              style: const TextStyle(
                  fontSize: TvTheme.fontTitle,
                  fontWeight: FontWeight.w700,
                  color: TvTheme.textPrimary)),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final s in _services) _card(context, s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, OnDemandService s) {
    final l10n = context.l10n;
    return SizedBox(
      width: 200,
      height: 176,
      child: TvFocusable(
        key: ValueKey('tv-ondemand-${s.id}'),
        // Servicios todavía sin conectar: se pueden enfocar pero no abren nada.
        onSelect: s.enabled ? () {} : null,
        builder: (context, focused) => Container(
          decoration: BoxDecoration(
            color: focused ? TvTheme.surfaceFocused : TvTheme.surface,
            borderRadius: BorderRadius.circular(TvTheme.radius),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(s.icon, size: 40, color: TvTheme.textPrimary),
              const SizedBox(height: 10),
              Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: TvTheme.fontBody,
                      fontWeight: FontWeight.w600,
                      color: TvTheme.textPrimary)),
              if (!s.enabled) ...[
                const SizedBox(height: 4),
                Text(l10n.onDemandComingSoon,
                    style: TextStyle(
                        fontSize: TvTheme.fontSmall,
                        color: TvTheme.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
