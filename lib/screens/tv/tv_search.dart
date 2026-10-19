import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/countries.dart';
import 'package:open_tv/backend/sql.dart' show pageSize;
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/screens/tv/player/tv_player.dart';
import 'package:open_tv/screens/tv/tv_channel_browser.dart'
    show TvAddToPlaylistCallback, TvPlayCallback;
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/tv_search_filters.dart';
import 'package:open_tv/screens/tv/widgets/tv_channel_card.dart';
import 'package:open_tv/screens/tv/widgets/tv_channel_menu.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';
import 'package:open_tv/screens/tv/widgets/tv_guide_dialog.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_text_field.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

enum _SearchStatus { idle, searching, results, empty, error }

/// Búsqueda de canales con el control remoto.
class TVSearch extends StatefulWidget {
  const TVSearch({
    super.key,
    this.data = const TvData(),
    this.onPlay,
    this.onAddToPlaylist,
  });

  final TvData data;
  final TvPlayCallback? onPlay;
  final TvAddToPlaylistCallback? onAddToPlaylist;

  @override
  State<TVSearch> createState() => _TVSearchState();
}

class _TVSearchState extends State<TVSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _fieldScope = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
  );
  final ScrollController _scroll = ScrollController();
  final Map<int, FocusNode> _nodes = {};

  Timer? _debounce;
  int _request = 0;
  bool _focusFirstOnResults = false;

  _SearchStatus _status = _SearchStatus.idle;
  String _query = '';
  String? _country;
  List<Channel> _results = [];
  bool _hasMore = false;
  bool _loadingMore = false;
  int _page = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _fieldScope.dispose();
    _scroll.dispose();
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _node(int i) => _nodes.putIfAbsent(i, FocusNode.new);

  Future<void> _pickCountry() async {
    final countries = await widget.data.countries();
    if (!mounted) return;
    if (countries.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text('Actualiza las listas para ver los países'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    final choice = await showTvOptions<String>(
      context,
      title: 'País',
      options: [
        ('Todos los países', ''),
        for (final c in countries)
          ('${countryName(c.code)} (${c.count})', c.code),
      ],
    );
    if (choice == null || !mounted) return;
    setState(() => _country = choice.isEmpty ? null : choice);
    await _search(_controller.text);
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(text),
    );
  }

  void _onSubmitted(String text) {
    _debounce?.cancel();
    _search(text, focusFirst: true);
  }

  Future<Filters?> _filters(String text, int page) async {
    final ids = await widget.data.enabledSourceIds();
    final filters = buildTvSearchFilters(text, ids, country: _country);
    filters?.page = page;
    return filters;
  }

  Future<void> _search(String text, {bool focusFirst = false}) async {
    final request = ++_request;
    _focusFirstOnResults = focusFirst;
    final query = text.trim();
    if (query.length < tvSearchMinChars && _country == null) {
      setState(() {
        _status = _SearchStatus.idle;
        _results = [];
        _hasMore = false;
        _loadingMore = false;
      });
      return;
    }
    setState(() {
      _status = _SearchStatus.searching;
      _query = query;
    });
    try {
      final filters = await _filters(text, 1);
      final items = filters == null
          ? <Channel>[]
          : await widget.data.searchChannels(filters);
      if (!mounted || request != _request) return;
      setState(() {
        _results = List.of(items);
        _page = 1;
        _hasMore = items.length >= pageSize;
        _loadingMore = false;
        _status = items.isEmpty ? _SearchStatus.empty : _SearchStatus.results;
      });
      if (_focusFirstOnResults && items.isNotEmpty) {
        _focusFirstOnResults = false;
        WidgetsBinding.instance.endOfFrame.then((_) {
          // requestFocus aplica el foco en un microtask: se espera a que el
          // campo lo recupere antes de comprobar que el usuario sigue en él.
          Future.microtask(() {
            if (mounted && request == _request && _fieldScope.hasFocus) {
              _focusResult(0);
            }
          });
        });
      }
    } catch (e) {
      debugPrint('TVSearch: error buscando "$query": $e');
      if (!mounted || request != _request) return;
      setState(() => _status = _SearchStatus.error);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _status != _SearchStatus.results) return;
    final request = _request;
    final next = _page + 1;
    setState(() => _loadingMore = true);
    List<Channel> items = [];
    try {
      final filters = await _filters(_controller.text, next);
      if (filters != null) items = await widget.data.searchChannels(filters);
    } catch (e) {
      debugPrint('TVSearch: error cargando más resultados: $e');
    }
    if (!mounted || request != _request) return;
    setState(() {
      _results.addAll(items);
      _page = next;
      _hasMore = items.length >= pageSize;
      _loadingMore = false;
    });
  }

  void _focusResult(int index) {
    if (index >= _results.length) return;
    final node = _node(index);
    if (node.context != null) {
      node.requestFocus();
      return;
    }
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _node(index).requestFocus();
    });
  }

  Future<void> _play(int index) async {
    final playlist = List.of(_results);
    final last = await (widget.onPlay ??
        (ctx, list, i) =>
            openTvPlayer(ctx, playlist: list, index: i, data: widget.data))(
      context,
      playlist,
      index,
    );
    if (!mounted || last == null) return;
    _focusResult(last);
  }

  Future<void> _toggleFavorite(int index) async {
    final channel = _results[index];
    final value = !channel.favorite;
    try {
      // El id puede haber cambiado si la fuente se refrescó mientras se navegaba.
      final id = await widget.data.resolveChannelId(channel);
      if (id == null) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text('Este canal ya no está disponible'),
            duration: Duration(seconds: 2),
          ));
        }
        return;
      }
      await widget.data.setFavorite(id, value);
    } catch (e) {
      debugPrint('TVSearch: error cambiando favorito: $e');
      return;
    }
    if (!mounted) return;
    setState(() => channel.favorite = value);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(value ? 'Agregado a favoritos' : 'Quitado de favoritos'),
      duration: const Duration(milliseconds: 800),
    ));
  }

  Future<void> _toggleDead(Channel channel) async {
    final wasDead = channel.dead;
    if (wasDead) {
      await widget.data.clearChannelDead(channel);
    } else {
      await widget.data.markChannelDead(channel);
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(wasDead ? 'Marca quitada' : 'Marcado como caído'),
      duration: const Duration(milliseconds: 800),
    ));
  }

  Future<void> _openMenu(int index) {
    final channel = _results[index];
    return showTvChannelMenu(
      context,
      channel: channel,
      onPlay: () => _play(index),
      onToggleFavorite: () => _toggleFavorite(index),
      onAddToPlaylist: widget.onAddToPlaylist == null
          ? null
          : () => widget.onAddToPlaylist!(context, channel),
      onShowGuide: widget.data.hasGuide(channel)
          ? () => showTvGuide(context, data: widget.data, channel: channel)
          : null,
      onToggleDead: () => _toggleDead(_results[index]),
    );
  }

  String _statusText() {
    switch (_status) {
      case _SearchStatus.idle:
        return 'Escribe al menos 2 letras o elige un país';
      case _SearchStatus.searching:
        return 'Buscando…';
      case _SearchStatus.results:
        return '${_results.length} resultados';
      case _SearchStatus.empty:
        return _query.isEmpty
            ? 'Sin canales de este país'
            : 'Sin resultados para "$_query"';
      case _SearchStatus.error:
        return 'Error al buscar. Intenta de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Focus(
            focusNode: _fieldScope,
            onKeyEvent: (node, event) {
              // ↓ desde el campo (en modo botón) entra al primer resultado.
              if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown &&
                  _results.isNotEmpty) {
                _focusResult(0);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Row(
              children: [
                Expanded(
                  child: TvTextField(
                    key: const ValueKey('tv-search-field'),
                    controller: _controller,
                    label: 'Buscar canales',
                    hint: 'Presiona OK para escribir',
                    icon: Icons.search,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: _onSubmitted,
                  ),
                ),
                const SizedBox(width: 16),
                TvFocusable(
                  key: const ValueKey('tv-search-country'),
                  scaleOnFocus: false,
                  onSelect: _pickCountry,
                  builder: (context, focused) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
                      borderRadius: BorderRadius.circular(TvTheme.radius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public, color: TvTheme.textPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'País: ${_country == null ? 'Todos' : countryName(_country!)}',
                          style: const TextStyle(
                            fontSize: TvTheme.fontBody,
                            color: TvTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _statusText(),
                style: TextStyle(
                  fontSize: TvTheme.fontSmall,
                  color: _status == _SearchStatus.error
                      ? TvTheme.error
                      : TvTheme.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_results.isEmpty) return const SizedBox.shrink();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) _loadMore();
        return false;
      },
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: TvTheme.tileMaxExtent,
          childAspectRatio: TvTheme.tileAspectRatio,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
        ),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final channel = _results[index];
          return TvFocusable(
            key: ValueKey('tv-search-result-$index'),
            focusNode: _node(index),
            onSelect: () => _play(index),
            onLongPress: () => _openMenu(index),
            builder: (context, focused) =>
                TvChannelCard(channel: channel, focused: focused),
          );
        },
      ),
    );
  }
}
