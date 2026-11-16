import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/ondemand/on_demand_play.dart';
import 'package:open_tv/screens/tv/widgets/tv_button.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

typedef OnDemandPlay = Future<void> Function(
    BuildContext context, OnDemandProvider provider, OnDemandTitle title);

/// Películas gratuitas de un servicio on demand: cuadrícula de carteles, y al
/// pulsar OK una ficha con la sinopsis y el botón «Ver».
class TvCatalogScreen extends StatefulWidget {
  const TvCatalogScreen({
    super.key,
    required this.provider,
    this.onPlay = playOnDemandTitle,
  });

  final OnDemandProvider provider;
  final OnDemandPlay onPlay;

  @override
  State<TvCatalogScreen> createState() => _TvCatalogScreenState();
}

class _TvCatalogScreenState extends State<TvCatalogScreen> {
  List<OnDemandTitle>? _titles;
  bool _failed = false;

  /// Categoría elegida; `null` = «Todas».
  String? _category;

  // Un nodo de foco por categoría (`null` = «Todas»), para volver a la elegida.
  final Map<String?, FocusNode> _catNodes = {};
  FocusNode _catNode(String? c) => _catNodes.putIfAbsent(c, FocusNode.new);

  @override
  void dispose() {
    for (final n in _catNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _titles = null;
      _failed = false;
      _category = null;
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
    } catch (e) {
      // Cualquier fallo (red, TLS…) muestra el error con «Reintentar».
      debugPrint('TvCatalogScreen: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openSheet(OnDemandTitle title) async {
    final watch = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MovieSheet(title: title),
    );
    if (watch == true && mounted) await widget.onPlay(context, widget.provider, title);
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
    final categories = _categoriesOf(titles);
    final visible = _category == null
        ? titles
        : [
            for (final t in titles)
              if (t.categories.contains(_category)) t
          ];
    final grid = _grid(visible);
    if (categories.isEmpty) return grid;
    // ← desde la cuadrícula vuelve a la categoría elegida (Flutter iría a la
    // más cercana en vertical, que con carteles altos suele ser otra).
    final guarded = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.arrowLeft) {
          return KeyEventResult.ignored;
        }
        FocusManager.instance.primaryFocus
            ?.focusInDirection(TraversalDirection.left);
        // El cambio de foco se aplica en una microtarea: se mira después.
        scheduleMicrotask(() {
          if (mounted && _catNodes.values.any((n) => n.hasFocus)) {
            _catNode(_category).requestFocus();
          }
        });
        return KeyEventResult.handled;
      },
      child: grid,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 240, child: _categoryColumn(l10n, categories)),
        const SizedBox(width: 12),
        Expanded(child: guarded),
      ],
    );
  }

  /// Categorías distintas de los títulos, en orden alfabético sin distinguir
  /// mayúsculas.
  static List<String> _categoriesOf(List<OnDemandTitle> titles) {
    final set = <String>{for (final t in titles) ...t.categories};
    return set.toList()
      ..sort((a, b) {
        final byLower = a.toLowerCase().compareTo(b.toLowerCase());
        return byLower != 0 ? byLower : a.compareTo(b);
      });
  }

  Widget _categoryColumn(AppLocalizations l10n, List<String> categories) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      children: [
        _categoryItem(const ValueKey('tv-cat-all'), l10n.onDemandAllCategories,
            node: _catNode(null),
            selected: _category == null,
            onSelect: () => setState(() => _category = null)),
        for (final c in categories)
          _categoryItem(ValueKey('tv-cat-$c'), c,
              node: _catNode(c),
              selected: _category == c,
              onSelect: () => setState(() => _category = c)),
      ],
    );
  }

  Widget _categoryItem(Key key, String label,
      {required FocusNode node,
      required bool selected,
      required VoidCallback onSelect}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocusable(
        key: key,
        focusNode: node,
        onSelect: onSelect,
        builder: (context, focused) => Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? TvTheme.accent
                : (focused ? TvTheme.surfaceFocused : TvTheme.surface),
            borderRadius: BorderRadius.circular(TvTheme.radius),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: TvTheme.fontBody,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: TvTheme.textPrimary)),
        ),
      ),
    );
  }

  Widget _grid(List<OnDemandTitle> titles) {
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
