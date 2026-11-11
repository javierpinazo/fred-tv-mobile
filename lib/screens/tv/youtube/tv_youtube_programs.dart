import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';
import 'package:open_tv/screens/tv/youtube/youtube_age_label.dart';

/// Reproduce [program] del canal [channel]; termina al cerrar el reproductor.
typedef YoutubePlay = Future<void> Function(
    BuildContext context, Channel channel, YoutubeProgram program);

typedef YoutubeThumbnailBuilder = Widget Function(
    BuildContext context, YoutubeProgram program);

/// Lo que se usa para reproducir cuando no se indica `onPlay`.
YoutubePlay defaultYoutubePlay = (context, channel, program) async {};

enum _Phase { loading, failed, ready }

/// Últimos programas de un canal de YouTube en mosaico: los directos en curso
/// primero y después del más reciente al más antiguo.
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

  @override
  State<TvYoutubePrograms> createState() => _TvYoutubeProgramsState();
}

class _TvYoutubeProgramsState extends State<TvYoutubePrograms> {
  _Phase _phase = _Phase.loading;
  List<YoutubeProgram> _programs = const [];
  List<FocusNode> _nodes = const [];
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _request++;
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final request = ++_request;
    setState(() => _phase = _Phase.loading);
    try {
      final programs =
          await widget.data.youtubePrograms(widget.channel, force: force);
      if (!mounted || request != _request) return;
      for (final n in _nodes) {
        n.dispose();
      }
      setState(() {
        _programs = programs;
        _nodes = [
          for (final p in programs) FocusNode(debugLabel: 'yt-${p.videoId}')
        ];
        _phase = _Phase.ready;
      });
    } catch (e) {
      debugPrint('TvYoutubePrograms: no se pudo cargar ${widget.channel.url}: $e');
      if (!mounted || request != _request) return;
      setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _play(int index) async {
    final play = widget.onPlay ?? defaultYoutubePlay;
    await play(context, widget.channel, _programs[index]);
    if (!mounted || index >= _nodes.length) return;
    _nodes[index].requestFocus();
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
        if (_programs.isEmpty) {
          return _message(
              icon: Icons.video_library_outlined, text: context.l10n.ytEmpty);
        }
        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: TvYoutubePrograms.columns,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 1.12,
          ),
          itemCount: _programs.length,
          itemBuilder: (context, index) {
            final program = _programs[index];
            return TvFocusable(
              key: ValueKey('yt-${program.videoId}'),
              focusNode: _nodes[index],
              autofocus: index == 0,
              onSelect: () => _play(index),
              builder: (context, focused) => _ProgramCard(
                program: program,
                focused: focused,
                thumbnailBuilder: widget.thumbnailBuilder,
              ),
            );
          },
        );
    }
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
    return Container(
      decoration: BoxDecoration(
        color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
        borderRadius: BorderRadius.circular(TvTheme.radius - 2),
      ),
      padding: const EdgeInsets.all(8),
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
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              program.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: TvTheme.fontSmall,
                color: TvTheme.textPrimary,
                height: 1.2,
              ),
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: program.isLive ? TvTheme.error : TvTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
