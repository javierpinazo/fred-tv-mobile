import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/tv_home.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

const String _defaultSourceName = 'IPTV Español';
const String _defaultSourceUrl =
    'https://iptv-org.github.io/iptv/languages/spa.m3u';

/// Primer arranque en TV: si no hay ninguna fuente, descarga la lista en
/// español de iptv-org y agrega los canales de prueba.
Future<void> ensureDefaultTvSources({TvData data = const TvData()}) async {
  if (await Sql.hasSources()) return;
  await data.addSource(Source(
    name: _defaultSourceName,
    url: _defaultSourceUrl,
    sourceType: SourceType.m3uUrl,
    enabled: true,
  ));
  await Sql.addTestChannels();
}

enum _Phase { preparing, failed, ready }

/// Pantalla de arranque de TV: carga inicial con feedback y paso al home.
class TvBootstrap extends StatefulWidget {
  const TvBootstrap({
    super.key,
    this.data = const TvData(),
    this.prepare,
    this.homeBuilder,
  });

  final TvData data;
  final Future<void> Function()? prepare;
  final WidgetBuilder? homeBuilder;

  @override
  State<TvBootstrap> createState() => _TvBootstrapState();
}

class _TvBootstrapState extends State<TvBootstrap> {
  _Phase _phase = _Phase.preparing;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() => _phase = _Phase.preparing);
    try {
      await (widget.prepare ?? () => ensureDefaultTvSources(data: widget.data))();
      if (!mounted) return;
      _goHome();
    } catch (e) {
      debugPrint('TvBootstrap: error preparando las fuentes: $e');
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  void _goHome() {
    if (_phase == _Phase.ready) return;
    setState(() => _phase = _Phase.ready);
    unawaited(widget.data.warmUpGuide());
    widget.data.autoRefreshEnabled().then((enabled) {
      if (enabled) unawaited(widget.data.refreshSources(onlyStale: true));
    }).catchError((Object e) {
      debugPrint('TvBootstrap: error iniciando la actualización: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.ready) {
      return widget.homeBuilder?.call(context) ?? TVHome(data: widget.data);
    }
    return Scaffold(
      backgroundColor: TvTheme.background,
      body: Center(
        child: _phase == _Phase.preparing ? _buildLoading() : _buildFailed(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.live_tv, size: 96, color: TvTheme.accent),
        SizedBox(height: 24),
        Text(
          'Preparando canales…',
          style: TextStyle(
            fontSize: TvTheme.fontTitle,
            color: TvTheme.textPrimary,
          ),
        ),
        SizedBox(height: 24),
        CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildFailed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 80, color: TvTheme.error),
        const SizedBox(height: 20),
        const Text(
          'No se pudo descargar la lista de canales',
          style: TextStyle(
            fontSize: TvTheme.fontTitle,
            color: TvTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(
              'Reintentar',
              key: const ValueKey('tv-bootstrap-retry'),
              autofocus: true,
              onSelect: _prepare,
            ),
            const SizedBox(width: 20),
            _button(
              'Continuar',
              key: const ValueKey('tv-bootstrap-continue'),
              onSelect: _goHome,
            ),
          ],
        ),
      ],
    );
  }

  Widget _button(
    String label, {
    required Key key,
    bool autofocus = false,
    required VoidCallback onSelect,
  }) {
    return TvFocusable(
      key: key,
      autofocus: autofocus,
      onSelect: onSelect,
      builder: (context, focused) => Container(
        constraints: const BoxConstraints(minWidth: 180, minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
          borderRadius: BorderRadius.circular(TvTheme.radius - 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: TvTheme.fontBody,
            color: TvTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
