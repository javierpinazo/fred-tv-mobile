import 'package:flutter/material.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/screens/tv/tv_channel_browser.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/tv_focus.dart';
import 'package:open_tv/screens/tv/tv_search.dart';
import 'package:open_tv/screens/tv/tv_settings.dart';
import 'package:open_tv/screens/tv/tv_user_playlists.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

const _tabs = <(String, IconData)>[
  ('Canales', Icons.live_tv),
  ('Favoritos', Icons.star),
  ('Mis listas', Icons.playlist_play),
  ('Buscar', Icons.search),
  ('Ajustes', Icons.settings),
];

/// Pantalla principal de TV: menú lateral + pestañas, cada una en su propio
/// FocusScope. La navegación ↑↓←→ la hace Flutter; solo los bordes saltan
/// entre el menú y el contenido.
class TVHome extends StatefulWidget {
  const TVHome({super.key, this.data = const TvData(), this.onPlay});

  final TvData data;
  final TvPlayCallback? onPlay;

  @override
  State<TVHome> createState() => _TVHomeState();
}

class _TVHomeState extends State<TVHome> {
  int _selectedIndex = 0;
  bool _sidebarFocused = true;
  bool _pendingReload = false;
  Key _browserKey = UniqueKey();
  final GlobalKey<TVChannelBrowserState> _favoritesKey = GlobalKey();
  final GlobalKey<TvUserPlaylistsScreenState> _playlistsKey = GlobalKey();

  final FocusScopeNode _sidebarScope = FocusScopeNode(debugLabel: 'tv-sidebar');
  final List<FocusScopeNode> _tabScopes =
      List.generate(_tabs.length, (i) => FocusScopeNode(debugLabel: 'tv-tab-$i'));
  final List<FocusNode> _navNodes = List.generate(_tabs.length, (_) => FocusNode());
  late final TvEdgeFocusAction _edgeAction = TvEdgeFocusAction(onEdge: _onEdge);

  @override
  void initState() {
    super.initState();
    _sidebarScope.addListener(_onSidebarFocus);
    tvSourcesVersion.addListener(_onSourcesChanged);
  }

  @override
  void dispose() {
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
            for (var i = 0; i < _tabs.length; i++)
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
    final (label, icon) = _tabs[index];
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
