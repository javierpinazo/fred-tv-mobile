import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/backend/youtube/youtube_show.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_player.dart';
import 'package:open_tv/screens/tv/youtube/youtube_age_label.dart';

/// Reproduce [program] del canal [channel]; termina al cerrar el reproductor.
typedef YoutubePlay = Future<void> Function(
    BuildContext context, Channel channel, YoutubeProgram program);

typedef YoutubeThumbnailBuilder = Widget Function(
    BuildContext context, YoutubeProgram program);

enum _Phase { loading, failed, ready }

const double _gridPadding = 10;
const double _gridSpacing = 18;

/// Programas de un canal de YouTube: hasta cinco filas, una por programa (la
/// del preferido arriba), y debajo todas las emisiones recientes en mosaico.
/// Mantener OK sobre una fila permite cambiarla de sitio.
class TvYoutubePrograms extends StatefulWidget {
  const TvYoutubePrograms({
    super.key,
    required this.channel,
    this.data = const TvData(),
    this.onPlay,
    this.thumbnailBuilder,
  });

  final Channel channel;
  final TvData data;
  final YoutubePlay? onPlay;
  final YoutubeThumbnailBuilder? thumbnailBuilder;

  static const int columns = 4;

  /// Filas de programa que se muestran como mucho.
  static const int maxShows = 5;

  @override
  State<TvYoutubePrograms> createState() => _TvYoutubeProgramsState();
}

class _TvYoutubeProgramsState extends State<TvYoutubePrograms> {
  _Phase _phase = _Phase.loading;
  List<YoutubeProgram> _programs = const [];
  List<YoutubeShow> _shows = const [];
  List<YoutubeShow> _rows = const [];

  /// Un nodo de foco por tarjeta: `<programa>-<vídeo>` en las filas y solo el
  /// vídeo en el mosaico.
  final Map<String, FocusNode> _nodes = {};
  final ScrollController _scroll = ScrollController();

  /// Alto de una fila de programa en el último dibujo, para llevar la vista
  /// hasta una fila que aún no está construida.
  double _rowHeight = 0;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _request++;
    _disposeNodes();
    _scroll.dispose();
    super.dispose();
  }

  void _disposeNodes() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    _nodes.clear();
  }

  FocusNode _node(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'yt-$id'));

  Future<void> _load({bool force = false}) async {
    final request = ++_request;
    setState(() => _phase = _Phase.loading);
    try {
      final page =
          await widget.data.youtubeChannelPage(widget.channel, force: force);
      final order = await widget.data.youtubeShowOrder(widget.channel);
      if (!mounted || request != _request) return;
      _disposeNodes();
      setState(() {
        _programs = page.programs;
        _shows = page.shows;
        _rows = arrangeYoutubeShows(page.shows,
            order: order, max: TvYoutubePrograms.maxShows);
        _phase = _Phase.ready;
      });
    } catch (e) {
      debugPrint(
          'TvYoutubePrograms: no se pudo cargar ${widget.channel.url}: $e');
      if (!mounted || request != _request) return;
      setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _play(String id, YoutubeProgram program) async {
    final play = widget.onPlay ?? openTvYoutubePlayer;
    await play(context, widget.channel, program);
    if (!mounted) return;
    _nodes[id]?.requestFocus();
  }

  /// Menú de OK largo sobre una emisión de la fila [show]: mover la fila.
  Future<void> _showMenu(YoutubeShow show, String id) async {
    final l10n = context.l10n;
    final keys = [for (final s in _rows) s.key];
    final index = keys.indexOf(show.key);
    if (index < 0) return;
    final options = [
      if (index > 0) (l10n.ytShowMoveFirst, YoutubeShowMove.first),
      if (index > 0) (l10n.ytShowMoveUp, YoutubeShowMove.up),
      if (index < keys.length - 1) (l10n.ytShowMoveDown, YoutubeShowMove.down),
    ];
    if (options.isEmpty) return;
    final move = await showTvOptions<YoutubeShowMove>(context,
        title: show.name, options: options);
    if (move == null || !mounted) return;
    final order = moveYoutubeShow(keys, show.key, move);
    setState(() {
      _rows = arrangeYoutubeShows(_shows,
          order: order, max: TvYoutubePrograms.maxShows);
    });
    // La fila puede haber quedado fuera de la pantalla (y sin construir):
    // primero se lleva la vista hasta ella y después se le devuelve el foco.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        final position = _scroll.position;
        _scroll.jumpTo((order.indexOf(show.key) * _rowHeight)
            .clamp(position.minScrollExtent, position.maxScrollExtent));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nodes[id]?.requestFocus();
      });
    });
    try {
      await widget.data.setYoutubeShowOrder(widget.channel, order);
    } catch (e) {
      debugPrint('TvYoutubePrograms: no se pudo guardar el orden: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvTheme.background,
      body: Padding(
        padding: TvTheme.safeArea,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_display, color: TvTheme.error, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: TvTheme.fontTitle,
                      fontWeight: FontWeight.w600,
                      color: TvTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.failed:
        return _message(
          icon: Icons.cloud_off,
          text: context.l10n.ytLoadFailed,
          action: TvFocusable(
            autofocus: true,
            onSelect: () => _load(force: true),
            builder: (context, focused) => Container(
              constraints: const BoxConstraints(minWidth: 160, minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TvTheme.accent,
                borderRadius: BorderRadius.circular(TvTheme.radius - 2),
              ),
              child: Text(
                context.l10n.commonRetry,
                style: const TextStyle(
                    fontSize: TvTheme.fontBody, color: TvTheme.textPrimary),
              ),
            ),
          ),
        );
      case _Phase.ready:
        if (_programs.isEmpty && _rows.isEmpty) {
          return _message(
              icon: Icons.video_library_outlined, text: context.l10n.ytEmpty);
        }
        return LayoutBuilder(builder: (context, constraints) {
          const columns = TvYoutubePrograms.columns;
          final tileWidth = (constraints.maxWidth -
                  2 * _gridPadding -
                  (columns - 1) * _gridSpacing) /
              columns;
          // El alto sigue al tamaño de letra elegido en Ajustes: así el
          // título nunca queda cortado a media línea.
          final scaler = MediaQuery.textScalerOf(context);
          final tileHeight = _ProgramCard.height(tileWidth, scaler);
          _rowHeight = _sectionTitleHeight(scaler) + _rowListHeight(tileHeight);
          return CustomScrollView(
            controller: _scroll,
            // Las filas de fuera de la pantalla deben existir para que la
            // flecha abajo encuentre a dónde ir.
            cacheExtent: 2 * tileHeight,
            slivers: [
              for (var i = 0; i < _rows.length; i++)
                SliverToBoxAdapter(
                  key: ValueKey('yt-row-${_rows[i].key}'),
                  child: _showRow(_rows[i], tileWidth, tileHeight,
                      autofocus: i == 0),
                ),
              if (_rows.isNotEmpty && _programs.isNotEmpty)
                SliverToBoxAdapter(
                    child: _sectionTitle(context.l10n.ytAllRecent)),
              SliverPadding(
                padding: const EdgeInsets.all(_gridPadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: _gridSpacing,
                    mainAxisSpacing: _gridSpacing,
                    mainAxisExtent: tileHeight,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: _programs.length,
                    (context, index) {
                      final program = _programs[index];
                      final id = program.videoId;
                      return TvFocusable(
                        key: ValueKey('yt-$id'),
                        focusNode: _node(id),
                        autofocus: index == 0 && _rows.isEmpty,
                        onSelect: () => _play(id, program),
                        builder: (context, focused) => _ProgramCard(
                          program: program,
                          focused: focused,
                          thumbnailBuilder: widget.thumbnailBuilder,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        });
    }
  }

  static const double _sectionLineHeight = 1.3;

  /// Alto del título de una sección; sigue al tamaño de letra de Ajustes.
  static double _sectionTitleHeight(TextScaler scaler) =>
      8 + (scaler.scale(TvTheme.fontBody) * _sectionLineHeight).ceilToDouble();

  /// Alto del carrusel: la tarjeta más el hueco para su borde y su aumento
  /// al enfocarla.
  static double _rowListHeight(double tileHeight) =>
      tileHeight + 2 * _gridPadding;

  Widget _sectionTitle(String text, {Key? key}) => Container(
        height: _sectionTitleHeight(MediaQuery.textScalerOf(context)),
        padding: const EdgeInsets.fromLTRB(_gridPadding, 6, _gridPadding, 2),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          key: key,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: TvTheme.fontBody,
            fontWeight: FontWeight.w700,
            height: _sectionLineHeight,
            color: TvTheme.textPrimary,
          ),
        ),
      );

  /// Una fila: el nombre del programa y sus emisiones en carrusel.
  Widget _showRow(YoutubeShow show, double tileWidth, double tileHeight,
      {required bool autofocus}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(show.name, key: Key('yt-show-${show.key}')),
        SizedBox(
          height: _rowListHeight(tileHeight),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(_gridPadding),
            itemCount: show.programs.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gridSpacing),
            itemBuilder: (context, index) {
              final program = show.programs[index];
              final id = '${show.key}-${program.videoId}';
              return SizedBox(
                width: tileWidth,
                child: TvFocusable(
                  key: ValueKey('yt-$id'),
                  focusNode: _node(id),
                  autofocus: autofocus && index == 0,
                  onSelect: () => _play(id, program),
                  onLongPress: () => _showMenu(show, id),
                  builder: (context, focused) => _ProgramCard(
                    program: program,
                    focused: focused,
                    thumbnailBuilder: widget.thumbnailBuilder,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _message({
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: TvTheme.textSecondary),
          const SizedBox(height: 18),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: TvTheme.fontTitle, color: TvTheme.textPrimary),
          ),
          if (action != null) ...[const SizedBox(height: 28), action],
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.focused,
    this.thumbnailBuilder,
  });

  final YoutubeProgram program;
  final bool focused;
  final YoutubeThumbnailBuilder? thumbnailBuilder;

  static const double _padding = 8;
  static const double _gap = 8;

  /// Margen para el borde de foco que dibuja `TvFocusable` (hasta 5 px por
  /// lado con alto contraste).
  static const double _frame = 12;
  static const double _titleSize = TvTheme.fontSmall;
  static const double _titleLineHeight = 1.2;
  static const double _subtitleSize = 14;
  static const double _subtitleLineHeight = 1.3;

  static double _titleHeight(TextScaler scaler) =>
      (2 * scaler.scale(_titleSize) * _titleLineHeight).ceilToDouble();

  static double _subtitleHeight(TextScaler scaler) =>
      (scaler.scale(_subtitleSize) * _subtitleLineHeight).ceilToDouble();

  /// Alto de la tarjeta para un ancho dado: miniatura 16:9, dos líneas de
  /// título y una de fecha.
  static double height(double width, TextScaler scaler) =>
      2 * _padding +
      (width - 2 * _padding) * 9 / 16 +
      _gap +
      _titleHeight(scaler) +
      4 +
      _subtitleHeight(scaler) +
      _frame;

  Widget _placeholder() => ColoredBox(
        color: TvTheme.surfaceRaised,
        child: Center(
          child: Icon(Icons.smart_display,
              color: TvTheme.textSecondary, size: 40),
        ),
      );

  Widget _badge(String text, {required Color color, bool bold = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: TvTheme.textPrimary,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final age = program.age;
    final subtitle = program.isLive
        ? l10n.ytLiveNow
        : (age == null ? '' : youtubeAgeLabel(l10n, age));
    final duration = program.duration;
    final scaler = MediaQuery.textScalerOf(context);
    return Container(
      decoration: BoxDecoration(
        color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
        borderRadius: BorderRadius.circular(TvTheme.radius - 2),
      ),
      padding: const EdgeInsets.all(_padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnailBuilder?.call(context, program) ??
                      CachedNetworkImage(
                        imageUrl: program.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _placeholder(),
                        errorWidget: (_, __, ___) => _placeholder(),
                      ),
                  if (program.isLive)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _badge(l10n.ytLive,
                          color: TvTheme.error, bold: true),
                    )
                  else if (duration != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _badge(duration, color: const Color(0xD0000000)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _gap),
          SizedBox(
            height: _titleHeight(scaler),
            child: Text(
              program.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: _titleSize,
                color: TvTheme.textPrimary,
                height: _titleLineHeight,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: _subtitleHeight(scaler),
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _subtitleSize,
                height: _subtitleLineHeight,
                color: program.isLive ? TvTheme.error : TvTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
