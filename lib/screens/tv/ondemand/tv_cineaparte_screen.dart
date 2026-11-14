import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/ondemand/on_demand_play.dart';
import 'package:open_tv/screens/tv/widgets/tv_button.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

typedef OnDemandPlay = Future<void> Function(
    BuildContext context, OnDemandTitle title);

/// Películas gratuitas de un servicio on demand: cuadrícula de carteles, y al
/// pulsar OK una ficha con la sinopsis y el botón «Ver».
class TvCineaparteScreen extends StatefulWidget {
  const TvCineaparteScreen({
    super.key,
    required this.provider,
    this.onPlay = playOnDemandTitle,
  });

  final OnDemandProvider provider;
  final OnDemandPlay onPlay;

  @override
  State<TvCineaparteScreen> createState() => _TvCineaparteScreenState();
}

class _TvCineaparteScreenState extends State<TvCineaparteScreen> {
  List<OnDemandTitle>? _titles;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _titles = null;
      _failed = false;
    });
    try {
      final titles = await widget.provider.titles();
      if (!mounted) return;
      // Un catálogo vacío es casi seguro que la web cambió: no se deja una
      // pantalla en blanco.
      setState(() {
        _titles = titles;
        _failed = titles.isEmpty;
      });
    } on OnDemandUnavailableException catch (e) {
      debugPrint('TvCineaparteScreen: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openSheet(OnDemandTitle title) async {
    final watch = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MovieSheet(title: title),
    );
    if (watch == true && mounted) await widget.onPlay(context, title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: TvTheme.background,
      body: Padding(
        padding: TvTheme.safeArea,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.provider.name,
                style: const TextStyle(
                    fontSize: TvTheme.fontTitle,
                    fontWeight: FontWeight.w700,
                    color: TvTheme.textPrimary)),
            const SizedBox(height: 16),
            Expanded(child: _body(context, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: TvTheme.error),
            const SizedBox(height: 16),
            Text(l10n.onDemandLoadError,
                style: const TextStyle(
                    fontSize: TvTheme.fontBody, color: TvTheme.textPrimary)),
            const SizedBox(height: 24),
            TvButton(
                label: l10n.commonRetry,
                onSelect: _load,
                primary: true,
                autofocus: true),
          ],
        ),
      );
    }
    final titles = _titles;
    if (titles == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.58,
      ),
      itemCount: titles.length,
      itemBuilder: (context, i) => _card(titles[i], autofocus: i == 0),
    );
  }

  Widget _card(OnDemandTitle title, {required bool autofocus}) {
    return TvFocusable(
      key: ValueKey('tv-cine-${title.id}'),
      autofocus: autofocus,
      onSelect: () => _openSheet(title),
      builder: (context, focused) => Container(
        decoration: BoxDecoration(
          color: focused ? TvTheme.surfaceFocused : TvTheme.surface,
          borderRadius: BorderRadius.circular(TvTheme.radius),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _poster(title.posterUrl)),
            const SizedBox(height: 8),
            Text(title.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: TvTheme.fontSmall, color: TvTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}

Widget _posterPlaceholder() => Container(
      color: TvTheme.logoPlate,
      alignment: Alignment.center,
      child: const Icon(Icons.movie_outlined,
          size: 40, color: TvTheme.textPrimary),
    );

Widget _poster(String url) {
  if (url.isEmpty) return _posterPlaceholder();
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _posterPlaceholder(),
      errorWidget: (_, __, ___) => _posterPlaceholder(),
    ),
  );
}

/// Ficha de una película. Se cierra con `true` si el usuario pulsa «Ver».
class _MovieSheet extends StatelessWidget {
  const _MovieSheet({required this.title});

  final OnDemandTitle title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      backgroundColor: TvTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 200, height: 290, child: _poster(title.posterUrl)),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.title,
                        style: const TextStyle(
                            fontSize: TvTheme.fontTitle,
                            fontWeight: FontWeight.w700,
                            color: TvTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text(title.details,
                        style: TextStyle(
                            fontSize: TvTheme.fontSmall,
                            color: TvTheme.textSecondary)),
                    const SizedBox(height: 16),
                    Text(title.synopsis,
                        maxLines: 7,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: TvTheme.fontBody,
                            color: TvTheme.textPrimary)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        TvButton(
                            key: const ValueKey('tv-cine-watch'),
                            label: l10n.onDemandWatch,
                            primary: true,
                            autofocus: true,
                            onSelect: () => Navigator.of(context).pop(true)),
                        const SizedBox(width: 20),
                        TvButton(
                            label: l10n.ytBack,
                            onSelect: () => Navigator.of(context).pop(false)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
