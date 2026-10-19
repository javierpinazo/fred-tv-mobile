import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/user_playlist.dart';
import 'package:open_tv/screens/tv/player/tv_player.dart';
import 'package:open_tv/screens/tv/tv_channel_browser.dart'
    show TvAddToPlaylistCallback, TvPlayCallback;
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_channel_card.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_list_row.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

const double _playlistRowExtent = 84;
const String _duplicateMessage = 'Ya existe una lista con ese nombre';

void _toast(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Text(text),
    duration: const Duration(seconds: 2),
  ));
}

bool _isDuplicate(Object e) => e is StateError && e.message == 'duplicate';

/// Diálogo "Agregar a una lista…": elige una lista existente o crea una nueva.
Future<void> showAddToPlaylistDialog(
  BuildContext context, {
  required TvData data,
  required Channel channel,
}) async {
  final lists = await data.userPlaylists();
  if (!context.mounted) return;
  final choice = await showTvOptions<int>(
    context,
    title: channel.name,
    options: [
      for (final p in lists) (p.name, p.id),
      ('Nueva lista', -1),
    ],
  );
  if (choice == null || !context.mounted) return;

  late int playlistId;
  late String playlistName;
  if (choice == -1) {
    final name = await showTvTextPrompt(
      context,
      title: 'Nueva lista',
      label: 'Nombre de la lista',
      confirmLabel: 'Crear',
    );
    if (name == null || !context.mounted) return;
    try {
      playlistId = await data.createUserPlaylist(name);
      playlistName = name;
    } catch (e) {
      if (!context.mounted) return;
      _toast(context,
          _isDuplicate(e) ? _duplicateMessage : 'No se pudo crear la lista');
      return;
    }
  } else {
    playlistId = choice;
    playlistName = lists.firstWhere((p) => p.id == choice).name;
  }
  final added = await data.addToUserPlaylist(playlistId, channel);
  if (!context.mounted) return;
  _toast(context,
      added ? 'Agregado a «$playlistName»' : 'Ya está en «$playlistName»');
}

/// Callback listo para pasar a las pantallas que ofrecen "Agregar a una lista…".
TvAddToPlaylistCallback tvAddToPlaylist(TvData data) =>
    (context, channel) =>
        showAddToPlaylistDialog(context, data: data, channel: channel);

/// Pestaña "Mis listas".
class TvUserPlaylistsScreen extends StatefulWidget {
  const TvUserPlaylistsScreen({
    super.key,
    this.data = const TvData(),
    this.onPlay,
  });

  final TvData data;
  final TvPlayCallback? onPlay;

  @override
  State<TvUserPlaylistsScreen> createState() => TvUserPlaylistsScreenState();
}

class TvUserPlaylistsScreenState extends State<TvUserPlaylistsScreen> {
  List<UserPlaylist> _playlists = [];
  int _selected = 0;
  List<Channel> _channels = [];
  bool _loading = true;
  int _request = 0;
  Timer? _debounce;

  int? _customSourceId;

  int _columns = 4;
  int _lastGridFocus = 0;

  final ScrollController _gridScroll = ScrollController();
  final ScrollController _listScroll = ScrollController();
  final Map<int, FocusNode> _gridNodes = {};
  final Map<int, FocusNode> _playlistNodes = {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _gridScroll.dispose();
    _listScroll.dispose();
    for (final n in _gridNodes.values) {
      n.dispose();
    }
    for (final n in _playlistNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _gridNode(int i) => _gridNodes.putIfAbsent(i, FocusNode.new);
  FocusNode _playlistNode(int i) => _playlistNodes.putIfAbsent(i, FocusNode.new);

  UserPlaylist? get _current =>
      _selected < _playlists.length ? _playlists[_selected] : null;

  // --- Carga --------------------------------------------------------------

  /// Recarga las listas (y los canales de la seleccionada).
  Future<void> reload({int? selectId}) async {
    final previousId = _current?.id;
    List<UserPlaylist> lists = [];
    try {
      lists = await widget.data.userPlaylists();
    } catch (e) {
      debugPrint('TvUserPlaylists: error cargando listas: $e');
    }
    if (!mounted) return;
    final wanted = selectId ?? previousId;
    final index = wanted == null ? 0 : lists.indexWhere((p) => p.id == wanted);
    setState(() {
      _playlists = lists;
      _selected = index < 0 ? 0 : index;
    });
    await _loadChannels();
  }

  Future<void> _loadChannels() async {
    final request = ++_request;
    final playlist = _current;
    if (playlist == null) {
      if (mounted) {
        setState(() {
          _channels = [];
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = true);
    List<Channel> channels = [];
    try {
      _customSourceId = await widget.data.customSourceId();
      channels = await widget.data.userPlaylistChannels(playlist.id);
    } catch (e) {
      debugPrint('TvUserPlaylists: error cargando canales: $e');
    }
    if (!mounted || request != _request) return;
    setState(() {
      _channels = channels;
      _loading = false;
    });
  }

  void _onPlaylistFocused(int index) {
    _debounce?.cancel();
    if (index == _selected) return;
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _selected = index);
      _loadChannels();
    });
  }

  // --- Foco ---------------------------------------------------------------

  void _focusGrid(int index) {
    final node = _gridNode(index);
    if (node.context != null) {
      node.requestFocus();
      return;
    }
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _gridNode(index).requestFocus();
    });
  }

  void _focusPlaylist(int index) {
    final node = _playlistNode(index);
    if (node.context != null) {
      node.requestFocus();
      return;
    }
    if (_listScroll.hasClients) {
      _listScroll.jumpTo((index * _playlistRowExtent)
          .clamp(0.0, _listScroll.position.maxScrollExtent));
    }
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _playlistNode(index).requestFocus();
    });
  }

  // --- Acciones sobre listas ----------------------------------------------

  Future<void> _createPlaylist() async {
    final name = await showTvTextPrompt(
      context,
      title: 'Nueva lista',
      label: 'Nombre de la lista',
      confirmLabel: 'Crear',
    );
    if (name == null || !mounted) return;
    try {
      final id = await widget.data.createUserPlaylist(name);
      await reload(selectId: id);
    } catch (e) {
      if (!mounted) return;
      _toast(context,
          _isDuplicate(e) ? _duplicateMessage : 'No se pudo crear la lista');
    }
  }

  Future<void> _openPlaylistMenu(int index) async {
    final playlist = _playlists[index];
    final choice = await showTvOptions<String>(
      context,
      title: playlist.name,
      options: [('Renombrar', 'rename'), ('Eliminar', 'delete')],
    );
    if (choice == null || !mounted) return;
    if (choice == 'rename') {
      final name = await showTvTextPrompt(
        context,
        title: 'Renombrar',
        label: 'Nombre de la lista',
        initial: playlist.name,
      );
      if (name == null || !mounted) return;
      try {
        await widget.data.renameUserPlaylist(playlist.id, name);
        await reload(selectId: playlist.id);
      } catch (e) {
        if (!mounted) return;
        _toast(context, _isDuplicate(e) ? _duplicateMessage : 'No se pudo renombrar');
      }
    } else {
      final confirmed = await showTvConfirm(
        context,
        message: '¿Eliminar la lista «${playlist.name}»?',
      );
      if (!confirmed || !mounted) return;
      await widget.data.deleteUserPlaylist(playlist.id);
      if (!mounted) return;
      await reload();
      if (!mounted) return;
      _focusPlaylist(_playlists.isEmpty ? 0 : _selected.clamp(0, _playlists.length - 1));
    }
  }

  // --- Acciones sobre canales ---------------------------------------------

  Future<void> _addChannelByUrl() async {
    final playlist = _current;
    if (playlist == null) return;
    final name = await showTvTextPrompt(
      context,
      title: 'Agregar canal por URL',
      label: 'Nombre del canal',
    );
    if (name == null || !mounted) return;
    final url = await showTvTextPrompt(
      context,
      title: 'Agregar canal por URL',
      label: 'URL del stream',
    );
    if (url == null || !mounted) return;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      _toast(context, 'La URL debe empezar con http:// o https://');
      return;
    }
    try {
      final channel = await widget.data.addManualChannel(name: name, url: url);
      await widget.data.addToUserPlaylist(playlist.id, channel);
      await reload(selectId: playlist.id);
    } catch (e) {
      debugPrint('TvUserPlaylists: error agregando canal manual: $e');
      if (mounted) _toast(context, 'No se pudo agregar el canal');
    }
  }

  Future<void> _play(int index) async {
    final last = await (widget.onPlay ??
        (ctx, list, i) =>
            openTvPlayer(ctx, playlist: list, index: i, data: widget.data))(
      context,
      List.of(_channels),
      index,
    );
    if (!mounted || last == null || last >= _channels.length) return;
    _focusGrid(last + 1);
  }

  Future<void> _openChannelMenu(int index) async {
    final playlist = _current;
    if (playlist == null) return;
    final channel = _channels[index];
    final choice = await showTvOptions<String>(
      context,
      title: channel.name,
      options: [
        ('Reproducir', 'play'),
        ('Mover antes', 'up'),
        ('Mover después', 'down'),
        ('Quitar de la lista', 'remove'),
        if (channel.sourceId == _customSourceId) ('Eliminar canal', 'delete'),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'play':
        await _play(index);
      case 'up':
      case 'down':
        final delta = choice == 'up' ? -1 : 1;
        await widget.data.moveInUserPlaylist(playlist.id, channel, delta);
        await _loadChannels();
        if (!mounted) return;
        // El foco se queda en el canal movido (si no pudo moverse, no cambia).
        final target = index + delta;
        final newIndex =
            target < 0 || target >= _channels.length ? index : target;
        _focusGrid(newIndex + 1);
      case 'delete':
        await widget.data.deleteManualChannel(channel);
        await reload(selectId: playlist.id);
        if (!mounted) return;
        _focusGrid(_channels.isEmpty ? 0 : index.clamp(0, _channels.length - 1) + 1);
      case 'remove':
        await widget.data.removeFromUserPlaylist(playlist.id, channel);
        await reload(selectId: playlist.id);
        if (!mounted) return;
        _focusGrid(_channels.isEmpty ? 0 : index.clamp(0, _channels.length - 1) + 1);
    }
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: TvTheme.groupsWidth, child: _buildPlaylists()),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildPlaylists() {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            _current != null) {
          _focusGrid(_lastGridFocus);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: TvTheme.surface,
        child: ListView.builder(
          controller: _listScroll,
          itemExtent: _playlistRowExtent,
          itemCount: _playlists.length + 1,
          itemBuilder: (context, index) {
            if (index == _playlists.length) {
              return Padding(
                padding: const EdgeInsets.all(4),
                child: TvListRow(
                  key: const ValueKey('tv-playlist-new'),
                  focusNode: _playlistNode(index),
                  icon: Icons.add,
                  title: 'Nueva lista',
                  onSelect: _createPlaylist,
                ),
              );
            }
            final playlist = _playlists[index];
            final selected = index == _selected;
            return Padding(
              padding: const EdgeInsets.all(4),
              child: TvListRow(
                key: ValueKey('tv-playlist-$index'),
                focusNode: _playlistNode(index),
                title: playlist.name,
                subtitle: '${playlist.channelCount} canales',
                trailing: selected
                    ? const Icon(Icons.chevron_right,
                        color: TvTheme.accent, size: 26)
                    : null,
                onFocusChange: (focused) {
                  if (focused) _onPlaylistFocused(index);
                },
                onSelect: () => _focusGrid(_lastGridFocus),
                onLongPress: () => _openPlaylistMenu(index),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_playlists.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Crea tu primera lista con «Nueva lista».',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: TvTheme.fontBody,
              color: TvTheme.textSecondary,
            ),
          ),
        ),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        if (_channels.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              'Esta lista está vacía. Mantén OK sobre cualquier canal y elige «Agregar a una lista…».',
              style: TextStyle(
                fontSize: TvTheme.fontSmall,
                color: TvTheme.textSecondary,
              ),
            ),
          ),
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 16.0;
        const spacing = 20.0;
        final cross = constraints.maxWidth - 2 * padding;
        _columns = (cross / (TvTheme.tileMaxExtent + spacing)).ceil().clamp(1, 24);
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) {
            // ← en la primera columna vuelve a la lista seleccionada.
            if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                _lastGridFocus % _columns == 0) {
              _focusPlaylist(_selected);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
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
            itemCount: _channels.length + 1,
            itemBuilder: (context, gridIndex) {
              if (gridIndex == 0) {
                return TvFocusable(
                  key: const ValueKey('tv-playlist-add-url'),
                  focusNode: _gridNode(0),
                  onFocusChange: (f) {
                    if (f) _lastGridFocus = 0;
                  },
                  onSelect: _addChannelByUrl,
                  builder: (context, focused) => Container(
                    decoration: BoxDecoration(
                      color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
                      borderRadius: BorderRadius.circular(TvTheme.radius - 2),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_link, size: 36, color: TvTheme.accent),
                        SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            'Agregar canal por URL',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: TvTheme.fontSmall,
                              color: TvTheme.textPrimary,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final index = gridIndex - 1;
              final channel = _channels[index];
              return TvFocusable(
                key: ValueKey('tv-playlist-channel-$index'),
                focusNode: _gridNode(gridIndex),
                onFocusChange: (f) {
                  if (f) _lastGridFocus = gridIndex;
                },
                onSelect: () => _play(index),
                onLongPress: () => _openChannelMenu(index),
                builder: (context, focused) =>
                    TvChannelCard(channel: channel, focused: focused),
              );
            },
          ),
        );
      },
    );
  }
}
