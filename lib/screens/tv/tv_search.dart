import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final filters = buildTvSearchFilters(text, ids);
    filters?.page = page;
    return filters;
  }

  Future<void> _search(String text, {bool focusFirst = false}) async {
    final request = ++_request;
    _focusFirstOnResults = focusFirst;
    final query = text.trim();
    if (query.length < tvSearchMinChars) {
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
      await widget.data.setFavorite(channel.id!, value);
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
    );
  }

  String _statusText() {
    switch (_status) {
      case _SearchStatus.idle:
        return 'Escribe al menos 2 letras';
      case _SearchStatus.searching:
        return 'Buscando…';
      case _SearchStatus.results:
        return '${_results.length} resultados';
      case _SearchStatus.empty:
        return 'Sin resultados para "$_query"';
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
