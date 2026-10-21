import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/tv_channel_browser.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/player/tv_player.dart';
import 'package:open_tv/screens/tv/tv_focus.dart';
import 'package:open_tv/screens/tv/tv_links.dart';
import 'package:open_tv/screens/tv/tv_platform.dart';
import 'package:open_tv/screens/tv/tv_search.dart';
import 'package:open_tv/screens/tv/tv_settings.dart';
import 'package:open_tv/screens/tv/tv_user_playlists.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

const _tabIcons = <IconData>[
  Icons.live_tv,
  Icons.star,
  Icons.playlist_play,
  Icons.search,
  Icons.settings,
];

List<String> _tabLabels(AppLocalizations l10n) => [
      l10n.navChannels,
      l10n.navFavorites,
      l10n.navMyLists,
      l10n.navSearch,
      l10n.navSettings,
    ];

/// Pantalla principal de TV: menú lateral + pestañas, cada una en su propio
/// FocusScope. La navegación ↑↓←→ la hace Flutter; solo los bordes saltan
/// entre el menú y el contenido.
class TVHome extends StatefulWidget {
  const TVHome({
    super.key,
    this.data = const TvData(),
    this.onPlay,
    this.platform = const TvPlatform(),
  });

  final TvData data;

  /// Puente con Android TV (enlaces de la pantalla de inicio y de la búsqueda).
  final TvPlatform platform;
  final TvPlayCallback? onPlay;

  @override
  State<TVHome> createState() => _TVHomeState();
}

class _TVHomeState extends State<TVHome> {
  int _selectedIndex = 0;
  bool _sidebarFocused = true;
  bool _pendingReload = false;
  Key _browserKey = UniqueKey();
  Key _searchKey = UniqueKey();
  String? _searchQuery;
  StreamSubscription<String>? _linkSub;
  final GlobalKey<TVChannelBrowserState> _favoritesKey = GlobalKey();
  final GlobalKey<TvUserPlaylistsScreenState> _playlistsKey = GlobalKey();

  final FocusScopeNode _sidebarScope = FocusScopeNode(debugLabel: 'tv-sidebar');
  final List<FocusScopeNode> _tabScopes =
      List.generate(_tabIcons.length, (i) => FocusScopeNode(debugLabel: 'tv-tab-$i'));
  final List<FocusNode> _navNodes = List.generate(_tabIcons.length, (_) => FocusNode());
  late final TvEdgeFocusAction _edgeAction = TvEdgeFocusAction(onEdge: _onEdge);

  @override
  void initState() {
    super.initState();
    _sidebarScope.addListener(_onSidebarFocus);
    tvSourcesVersion.addListener(_onSourcesChanged);
    _linkSub = widget.platform.links.listen(_onLink);
    widget.platform.initialLink().then(_onLink);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _sidebarScope.removeListener(_onSidebarFocus);
    tvSourcesVersion.removeListener(_onSourcesChanged);
    _sidebarScope.dispose();
    for (final s in _tabScopes) {
      s.dispose();
    }
    for (final n in _navNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // --- Enlaces de Android TV ----------------------------------------------

  Future<void> _onLink(String? raw) async {
    final link = parseTvLink(raw);
    if (link == null || !mounted) return;
    switch (link) {
      case TvSearchLink(:final query):
        setState(() {
          _searchQuery = query;
          _searchKey = UniqueKey();
          _selectedIndex = 3;
        });
        WidgetsBinding.instance.endOfFrame.then((_) {
          if (mounted) _navNodes[3].requestFocus();
        });
      case TvPlayLink(:final name, :final source):
        Channel? channel;
        try {
          channel = await widget.data.findChannel(name, sourceName: source);
        } catch (e) {
          debugPrint('TVHome: error buscando el canal del enlace: $e');
        }
        if (!mounted) return;
        if (channel == null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            content: Text(context.l10n.linkChannelUnavailable),
            duration: const Duration(seconds: 3),
          ));
          return;
        }
        final play = widget.onPlay ??
            (ctx, list, i) =>
                openTvPlayer(ctx, playlist: list, index: i, data: widget.data);
        await play(context, [channel], 0);
    }
  }

  // --- Foco ---------------------------------------------------------------

  void _onSidebarFocus() {
    final has = _sidebarScope.hasFocus;
    if (has != _sidebarFocused && mounted) {
      setState(() => _sidebarFocused = has);
    }
    if (has) _applyPendingReload();
  }

  void _onEdge(TraversalDirection direction) {
    final inSidebar = _sidebarScope.hasFocus;
    if (direction == TraversalDirection.left && !inSidebar) {
      _focusSidebar();
    } else if (direction == TraversalDirection.right && inSidebar) {
      _enterContent();
    }
  }

  void _focusSidebar() => _navNodes[_selectedIndex].requestFocus();

  /// Entra al contenido de la pestaña activa; si no tiene nada enfocable
  /// (cargando, vacía) el foco se queda en el menú.
  void _enterContent() => focusFirstIn(_tabScopes[_selectedIndex]);

  void _onNavFocused(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    if (index == 1) _favoritesKey.currentState?.reload();
    if (index == 2) _playlistsKey.currentState?.reload();
  }

  // --- Recarga tras cambios en las fuentes --------------------------------

  void _onSourcesChanged() {
    _pendingReload = true;
    if (_sidebarScope.hasFocus) _applyPendingReload();
  }

  /// Los datos nuevos se aplican solo con el foco en el menú, nunca mientras
  /// el usuario navega el contenido.
  void _applyPendingReload() {
    if (!_pendingReload || !mounted) return;
    _pendingReload = false;
    setState(() => _browserKey = UniqueKey());
    _favoritesKey.currentState?.reload();
    _playlistsKey.currentState?.reload();
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _sidebarFocused,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _focusSidebar();
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DirectionalFocusIntent: _edgeAction,
        },
        child: Scaffold(
          backgroundColor: TvTheme.background,
          body: Padding(
            padding: TvTheme.safeArea,
            child: Row(
              children: [
                _buildSidebar(),
                const SizedBox(width: 8),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return FocusScope(
      node: _sidebarScope,
      child: AnimatedContainer(
        duration: TvTheme.focusDuration,
        width: _sidebarFocused
            ? TvTheme.sidebarExpanded
            : TvTheme.sidebarCollapsed,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: TvTheme.surface,
          borderRadius: BorderRadius.circular(TvTheme.radius + 4),
        ),
        child: Column(
          children: [
            for (var i = 0; i < _tabIcons.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildNavItem(i),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final label = _tabLabels(context.l10n)[index];
    final icon = _tabIcons[index];
    return TvFocusable(
      key: ValueKey('tv-nav-$index'),
      focusNode: _navNodes[index],
      autofocus: index == 0,
      scaleOnFocus: false,
      onFocusChange: (focused) {
        if (focused) _onNavFocused(index);
      },
      onSelect: _enterContent,
      builder: (context, focused) {
        final selected = index == _selectedIndex;
        final color = focused || selected ? Colors.white : TvTheme.textSecondary;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: focused
                ? TvTheme.accent
                : (selected
                    ? TvTheme.accent.withValues(alpha: 0.25)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(TvTheme.radius - 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              if (_sidebarFocused)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: TvTheme.fontBody,
                        color: color,
                        fontWeight:
                            focused || selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final addToPlaylist = tvAddToPlaylist(widget.data);
    final tabs = <Widget>[
      TVChannelBrowser(
        key: _browserKey,
        data: widget.data,
        onPlay: widget.onPlay,
        onAddToPlaylist: addToPlaylist,
      ),
      TVChannelBrowser(
        key: _favoritesKey,
        favoritesOnly: true,
        data: widget.data,
        onPlay: widget.onPlay,
        onAddToPlaylist: addToPlaylist,
      ),
      TvUserPlaylistsScreen(
        key: _playlistsKey,
        data: widget.data,
        onPlay: widget.onPlay,
      ),
      TVSearch(
        key: _searchKey,
        initialQuery: _searchQuery,
        data: widget.data,
        onPlay: widget.onPlay,
        onAddToPlaylist: addToPlaylist,
      ),
      TVSettings(data: widget.data),
    ];
    return IndexedStack(
      index: _selectedIndex,
      children: [
        for (var i = 0; i < tabs.length; i++)
          ExcludeFocus(
            excluding: i != _selectedIndex,
            child: FocusScope(node: _tabScopes[i], child: tabs[i]),
          ),
      ],
    );
  }
}
