import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/sql.dart' show pageSize;
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/screens/tv/player/tv_player.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_channel_card.dart';
import 'package:open_tv/screens/tv/widgets/tv_channel_menu.dart';
import 'package:open_tv/screens/tv/widgets/tv_guide_dialog.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

typedef TvPlayCallback = Future<int?> Function(
    BuildContext context, List<Channel> playlist, int index);

typedef TvAddToPlaylistCallback = Future<void> Function(
    BuildContext context, Channel channel);

const String _allChannelsLabel = 'Todos los canales';
const String _recentsLabel = 'Recientes';
const double _groupRowExtent = 56;
const int _maxGroupPages = 20;

/// Explorador de canales: grupos a la izquierda y grilla de canales.
class TVChannelBrowser extends StatefulWidget {
  const TVChannelBrowser({
    super.key,
    this.favoritesOnly = false,
    this.data = const TvData(),
    this.onPlay,
    this.onAddToPlaylist,
  });

  final bool favoritesOnly;
  final TvData data;
  final TvPlayCallback? onPlay;
  final TvAddToPlaylistCallback? onAddToPlaylist;

  @override
  State<TVChannelBrowser> createState() => TVChannelBrowserState();
}

class TVChannelBrowserState extends State<TVChannelBrowser> {
  // Grupos: el índice 0 es "Todos los canales" (sin filtro).
  List<String> _groups = [];
  bool _loadingGroups = true;
  int _selectedGroup = 0;
  Timer? _groupDebounce;

  // Canales del grupo seleccionado.
  List<Channel> _channels = [];
  bool _loadingChannels = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _requestId = 0;
  int _lastFocusedChannel = 0;

  // Geometría de la grilla (se recalcula en cada layout).
  int _columns = 4;
  double _rowExtent = 138;

  final ScrollController _gridScroll = ScrollController();
  final ScrollController _groupScroll = ScrollController();
  final Map<int, FocusNode> _channelNodes = {};
  final Map<int, FocusNode> _groupNodes = {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _groupDebounce?.cancel();
    _gridScroll.dispose();
    _groupScroll.dispose();
    for (final n in _channelNodes.values) {
      n.dispose();
    }
    for (final n in _groupNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _channelNode(int i) => _channelNodes.putIfAbsent(i, FocusNode.new);
  FocusNode _groupNode(int i) => _groupNodes.putIfAbsent(i, FocusNode.new);

  // --- Carga --------------------------------------------------------------

  /// Recarga grupos y canales desde cero.
  Future<void> reload() async {
    _groupDebounce?.cancel();
    if (widget.favoritesOnly) {
      if (mounted) setState(() => _loadingGroups = false);
      await _loadFirstPage();
      return;
    }
    if (mounted) setState(() => _loadingGroups = true);
    final names = <String>[];
    try {
      final ids = await widget.data.enabledSourceIds();
      for (var page = 1; page <= _maxGroupPages; page++) {
        final batch = await widget.data.searchGroups(Filters(
          viewType: ViewType.categories,
          sourceIds: ids,
          mediaTypes: [MediaType.livestream],
          page: page,
        ));
        names.addAll(batch.map((g) => g.name));
        if (batch.length < pageSize) break;
      }
    } catch (e) {
      debugPrint('TVChannelBrowser: error cargando grupos: $e');
    }
    var hasRecents = false;
    try {
      hasRecents = await widget.data.hasRecents();
    } catch (e) {
      debugPrint('TVChannelBrowser: error leyendo el historial: $e');
    }
    if (!mounted) return;
    setState(() {
      _groups = [_allChannelsLabel, if (hasRecents) _recentsLabel, ...names];
      _selectedGroup = 0;
      _loadingGroups = false;
    });
    await _loadFirstPage();
  }

  Future<List<Channel>> _fetch(int page) async {
    final ids = await widget.data.enabledSourceIds();
    final selected = widget.favoritesOnly || _selectedGroup == 0
        ? null
        : _groups[_selectedGroup];
    final recents = selected == _recentsLabel;
    final groupName = recents ? null : selected;
    return widget.data.searchChannels(Filters(
      viewType: widget.favoritesOnly
          ? ViewType.favorites
          : (recents ? ViewType.history : ViewType.all),
      sourceIds: ids,
      mediaTypes: widget.favoritesOnly
          ? [MediaType.livestream, MediaType.movie]
          : [MediaType.livestream],
      page: page,
      groupName: groupName,
    ));
  }

  Future<void> _loadFirstPage() async {
    final request = ++_requestId;
    if (mounted) {
      setState(() {
        _loadingChannels = true;
        _loadingMore = false;
        _hasMore = true;
        _page = 1;
        _channels = [];
        _lastFocusedChannel = 0;
      });
    }
    List<Channel> items = [];
    try {
      items = await _fetch(1);
    } catch (e) {
      debugPrint('TVChannelBrowser: error cargando canales: $e');
    }
    if (!mounted || request != _requestId) return;
    setState(() {
      _channels = List.of(items);
      _hasMore = items.length >= pageSize;
      _loadingChannels = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loadingChannels) return;
    final request = _requestId;
    final next = _page + 1;
    setState(() => _loadingMore = true);
    List<Channel> items = [];
    try {
      items = await _fetch(next);
    } catch (e) {
      debugPrint('TVChannelBrowser: error cargando más canales: $e');
    }
    if (!mounted || request != _requestId) return;
    setState(() {
      _channels.addAll(items);
      _page = next;
      _hasMore = items.length >= pageSize;
      _loadingMore = false;
    });
  }

  // --- Grupos -------------------------------------------------------------

  void _onGroupFocused(int index) {
    _groupDebounce?.cancel();
    if (index == _selectedGroup) return;
    _groupDebounce =
        Timer(const Duration(milliseconds: 300), () => _selectGroup(index));
  }

  Future<void> _selectGroup(int index) async {
    _groupDebounce?.cancel();
    if (!mounted || index == _selectedGroup) return;
    setState(() => _selectedGroup = index);
    await _loadFirstPage();
  }

  void _focusGroup(int index) {
    final node = _groupNode(index);
    if (node.context != null) {
      node.requestFocus();
      return;
    }
    if (_groupScroll.hasClients) {
      _groupScroll.jumpTo((index * _groupRowExtent)
          .clamp(0.0, _groupScroll.position.maxScrollExtent));
    }
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _groupNode(index).requestFocus();
    });
  }

  Future<void> _onGroupSelect(int index) async {
    await _selectGroup(index);
    if (mounted && _channels.isNotEmpty) _focusChannel(0);
  }

  // --- Canales ------------------------------------------------------------

  void _focusChannel(int index) {
    final node = _channelNode(index);
    if (node.context != null) {
      node.requestFocus();
      return;
    }
    if (_gridScroll.hasClients) {
      _gridScroll.jumpTo(((index ~/ _columns) * _rowExtent)
          .clamp(0.0, _gridScroll.position.maxScrollExtent));
    }
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _channelNode(index).requestFocus();
    });
  }

  Future<void> _play(int index) async {
    final playlist = List.of(_channels);
    final last = await (widget.onPlay ??
        (ctx, list, i) =>
            openTvPlayer(ctx, playlist: list, index: i, data: widget.data))(
      context,
      playlist,
      index,
    );
    if (!mounted || last == null || last >= _channels.length) return;
    _focusChannel(last);
  }

  Future<void> _toggleFavorite(int index) async {
    final channel = _channels[index];
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
      debugPrint('TVChannelBrowser: error cambiando favorito: $e');
      return;
    }
    if (!mounted) return;
    final removed = widget.favoritesOnly && !value;
    setState(() {
      channel.favorite = value;
      if (removed) _channels.removeAt(index);
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(value ? 'Agregado a favoritos' : 'Quitado de favoritos'),
      duration: const Duration(milliseconds: 800),
    ));
    if (removed && _channels.isNotEmpty) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) _focusChannel(index.clamp(0, _channels.length - 1));
      });
    }
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
    final channel = _channels[index];
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
      onToggleDead: () => _toggleDead(_channels[index]),
    );
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              if (!widget.favoritesOnly)
                SizedBox(width: TvTheme.groupsWidth, child: _buildGroups()),
              Expanded(child: _buildGrid()),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            'OK Reproducir  ·  Mantén OK Opciones  ·  ← Menú',
            style: TextStyle(
              fontSize: TvTheme.fontSmall,
              color: TvTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroups() {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        // → entra a la grilla (en lugar del tile más cercano en pantalla).
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            _channels.isNotEmpty) {
          _focusChannel(_lastFocusedChannel.clamp(0, _channels.length - 1));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: TvTheme.surface,
        child: ListView.builder(
          controller: _groupScroll,
          itemExtent: _groupRowExtent,
          itemCount: _groups.length,
          itemBuilder: (context, index) {
            final selected = index == _selectedGroup;
            return TvFocusable(
              key: ValueKey('tv-group-$index'),
              focusNode: _groupNode(index),
              scaleOnFocus: false,
              onFocusChange: (focused) {
                if (focused) _onGroupFocused(index);
              },
              onSelect: () => _onGroupSelect(index),
              builder: (context, focused) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: focused ? TvTheme.surfaceRaised : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: selected ? TvTheme.accent : Colors.transparent,
                      width: 4,
                    ),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  _groups[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: TvTheme.fontBody,
                    color: selected || focused
                        ? TvTheme.textPrimary
                        : TvTheme.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_loadingChannels) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            widget.favoritesOnly
                ? 'Aún no tienes favoritos. Mantén presionado OK sobre un canal para agregarlo.'
                : 'No hay canales en este grupo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: TvTheme.fontBody,
              color: TvTheme.textSecondary,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 16.0;
        const spacing = 20.0;
        final cross = constraints.maxWidth - 2 * padding;
        _columns = (cross / (TvTheme.tileMaxExtent + spacing)).ceil().clamp(1, 24);
        final tileWidth = (cross - (_columns - 1) * spacing) / _columns;
        _rowExtent = tileWidth / TvTheme.tileAspectRatio + spacing;
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) {
            // ← en la primera columna vuelve al grupo seleccionado.
            if (!widget.favoritesOnly &&
                (event is KeyDownEvent || event is KeyRepeatEvent) &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                _lastFocusedChannel % _columns == 0) {
              _focusGroup(_selectedGroup);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
                _loadMore();
              }
              return false;
            },
            child: GridView.builder(
              controller: _gridScroll,
              padding: const EdgeInsets.all(padding),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: TvTheme.tileMaxExtent,
                childAspectRatio: TvTheme.tileAspectRatio,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
              ),
              itemCount: _channels.length + (_loadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _channels.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final channel = _channels[index];
                return TvFocusable(
                  key: ValueKey('tv-channel-$index'),
                  focusNode: _channelNode(index),
                  onFocusChange: (focused) {
                    if (focused) _lastFocusedChannel = index;
                  },
                  onSelect: () => _play(index),
                  onLongPress: () => _openMenu(index),
                  builder: (context, focused) =>
                      TvChannelCard(channel: channel, focused: focused),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
