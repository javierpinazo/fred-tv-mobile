import 'package:flutter/material.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/backend/sql.dart' show customSourceName;
import 'package:open_tv/models/source.dart';
import 'package:open_tv/screens/tv/player/tv_buffer.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';
import 'package:open_tv/backend/backup_sql.dart';
import 'package:open_tv/screens/tv/tv_appearance.dart';
import 'package:open_tv/screens/tv/widgets/tv_pin_dialog.dart';
import 'package:open_tv/screens/tv/tv_add_m3u_screen.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/tv_iptv_org_screen.dart';
import 'package:open_tv/screens/tv/tv_time.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';
import 'package:open_tv/screens/tv/widgets/tv_list_row.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

class _SourceEntry {
  const _SourceEntry(this.source, this.lastRefresh);

  final Source source;
  final DateTime? lastRefresh;
}

/// Ajustes de TV: alta de listas, actualización y gestión de fuentes.
class TVSettings extends StatefulWidget {
  const TVSettings({super.key, this.data = const TvData()});

  final TvData data;

  @override
  State<TVSettings> createState() => _TVSettingsState();
}

class _TVSettingsState extends State<TVSettings> {
  List<_SourceEntry> _entries = [];
  bool _autoRefresh = true;
  int _bufferSecs = TvBuffer.defaultSeconds;
  TvEngineMode _engineMode = TvEngineMode.auto;
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _hideDead = false;
  bool _hideAdult = false;
  bool _zeroCopy = false;
  String? _epgUrl;
  String? _cameraUrl;
  bool _hasPin = false;
  int _deadCount = 0;
  String? _message;
  bool _messageIsError = false;
  final FocusNode _topNode = FocusNode();

  @override
  void initState() {
    super.initState();
    tvSourcesVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    tvSourcesVersion.removeListener(_load);
    _topNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final sources = await widget.data.sources();
      final entries = <_SourceEntry>[];
      for (final s in sources) {
        if (s.name == customSourceName || s.id == null) continue;
        entries.add(_SourceEntry(s, await widget.data.lastRefresh(s.id!)));
      }
      final auto = await widget.data.autoRefreshEnabled();
      final buffer = await widget.data.bufferSeconds();
      final engine = await widget.data.videoEngineMode();
      final scale = await widget.data.textScaleSetting();
      final contrast = await widget.data.highContrastSetting();
      final hideDead = await widget.data.hideDeadSetting();
      final hideAdult = await widget.data.hideAdultSetting();
      final zeroCopy = await widget.data.mpvZeroCopySetting();
      final epgUrl = await widget.data.epgUrlSetting();
      final cameraUrl = await widget.data.cameraUrlSetting();
      final hasPin = await widget.data.parentalPinSet();
      final deadCount = await widget.data.deadChannelCount();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _autoRefresh = auto;
        _bufferSecs = buffer;
        _engineMode = engine;
        _textScale = scale;
        _highContrast = contrast;
        _hideDead = hideDead;
        _hideAdult = hideAdult;
        _zeroCopy = zeroCopy;
        _epgUrl = epgUrl;
        _cameraUrl = cameraUrl;
        _hasPin = hasPin;
        _deadCount = deadCount;
      });
    } catch (e) {
      debugPrint('TVSettings: error cargando fuentes: $e');
    }
  }

  void _setMessage(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageIsError = error;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _load();
  }

  Future<void> _refreshNow({int? onlySourceId}) async {
    if (widget.data.isRefreshing) {
      _setMessage('Ya se están actualizando las listas');
      return;
    }
    _setMessage('Actualizando listas…');
    try {
      final result =
          await widget.data.refreshSources(onlySourceId: onlySourceId);
      if (result.failedNames.isNotEmpty) {
        _setMessage(
            '${result.failedNames.length} listas no se pudieron actualizar',
            error: true);
      } else {
        _setMessage('Listas actualizadas');
      }
    } catch (e) {
      debugPrint('TVSettings: error actualizando: $e');
      _setMessage('No se pudieron actualizar las listas', error: true);
    }
    if (mounted) _load();
  }

  Future<void> _toggleAuto() async {
    final value = !_autoRefresh;
    await widget.data.setAutoRefreshEnabled(value);
    if (mounted) setState(() => _autoRefresh = value);
  }

  Future<void> _cycleBuffer() async {
    final value = TvBuffer.next(_bufferSecs);
    await widget.data.setBufferSeconds(value);
    if (mounted) setState(() => _bufferSecs = value);
  }

  Future<void> _cycleTextScale() async {
    final next = TvAppearance.nextScale(_textScale);
    await widget.data.setTextScaleSetting(next);
    TvAppearance.textScale.value = next;
    if (mounted) setState(() => _textScale = next);
  }

  /// Pide el PIN actual; `true` si es correcto (avisa si no).
  Future<bool> _verifyPin(String title) async {
    final entered = await showTvPinPrompt(context, title: title);
    if (entered == null || !mounted) return false;
    if (await widget.data.verifyParentalPin(entered)) return true;
    _setMessage('PIN incorrecto', error: true);
    return false;
  }

  /// Pide un PIN nuevo dos veces; `null` si se cancela o no coinciden.
  Future<String?> _askNewPin() async {
    final first = await showTvPinPrompt(context, title: 'Nuevo PIN');
    if (first == null || !mounted) return null;
    final second = await showTvPinPrompt(context, title: 'Repite el PIN');
    if (second == null || !mounted) return null;
    if (first != second) {
      _setMessage('Los PIN no coinciden', error: true);
      return null;
    }
    return first;
  }

  Future<void> _toggleHideAdult() async {
    final next = !_hideAdult;
    // Activar es libre; desactivar exige el PIN si hay uno.
    if (!next && _hasPin && !await _verifyPin('Introduce el PIN')) return;
    await widget.data.setHideAdultSetting(next);
    if (mounted) setState(() => _hideAdult = next);
  }

  Future<void> _managePin() async {
    if (!_hasPin) {
      final pin = await _askNewPin();
      if (pin == null) return;
      await widget.data.setParentalPin(pin);
      if (mounted) setState(() => _hasPin = true);
      _setMessage('PIN guardado');
      return;
    }
    if (!await _verifyPin('Introduce el PIN actual')) return;
    final choice = await showTvOptions<int>(
      context,
      title: 'PIN de control parental',
      options: const [('Cambiar PIN', 0), ('Quitar PIN', 1)],
    );
    if (choice == null || !mounted) return;
    if (choice == 1) {
      await widget.data.setParentalPin(null);
      if (mounted) setState(() => _hasPin = false);
      _setMessage('PIN quitado');
      return;
    }
    final pin = await _askNewPin();
    if (pin == null) return;
    await widget.data.setParentalPin(pin);
    _setMessage('PIN guardado');
  }

  static String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

  Future<void> _backupMenu() async {
    final choice = await showTvOptions<String>(
      context,
      title: 'Copia de seguridad',
      options: const [
        ('Exportar copia', 'export'),
        ('Importar copia…', 'import'),
      ],
    );
    if (choice == 'export') await _exportBackup();
    if (choice == 'import') await _importBackupMenu();
  }

  Future<void> _exportBackup() async {
    try {
      final path = await widget.data.exportBackupToFile();
      _setMessage('Copia guardada en $path');
    } catch (e) {
      debugPrint('TVSettings: error exportando: $e');
      _setMessage('No se pudo guardar la copia', error: true);
    }
  }

  Future<void> _importBackupMenu() async {
    List<String> files = const [];
    try {
      files = await widget.data.listBackupFiles();
    } catch (e) {
      debugPrint('TVSettings: error listando copias: $e');
    }
    if (!mounted) return;
    final choice = await showTvOptions<String>(
      context,
      title: 'Importar copia',
      options: [
        for (final f in files) (_fileName(f), 'file:$f'),
        ('Desde una URL…', 'url'),
        ('Desde un archivo del dispositivo…', 'picker'),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice.startsWith('file:')) {
      await _runImport(
          () => widget.data.importBackupFromFile(choice.substring(5)));
    } else if (choice == 'url') {
      final url = await showTvTextPrompt(
        context,
        title: 'Importar desde una URL',
        label: 'Dirección de la copia (.json)',
        confirmLabel: 'Importar',
      );
      if (url == null || !mounted) return;
      await _runImport(() => widget.data.importBackupFromUrl(url));
    } else {
      final path = await widget.data.pickBackupFile();
      if (path == null || !mounted) {
        _setMessage('No se eligió ningún archivo', error: true);
        return;
      }
      await _runImport(() => widget.data.importBackupFromFile(path));
    }
  }

  Future<void> _runImport(Future<BackupResult> Function() run) async {
    _setMessage('Importando…');
    try {
      final result = await run();
      _setMessage('Copia importada: ${result.summary}');
    } on BackupFormatException catch (e) {
      _setMessage(e.message, error: true);
    } catch (e) {
      debugPrint('TVSettings: error importando: $e');
      _setMessage('No se pudo importar la copia', error: true);
    }
    if (mounted) _load();
  }

  Future<void> _editEpgUrl() async {
    final url = await showTvTextPrompt(
      context,
      title: 'Guía personalizada (XMLTV)',
      label: 'Dirección (.xml o .xml.gz); vacío para quitarla',
      initial: _epgUrl ?? '',
    );
    // `null` = cancelado (el prompt devuelve null también con texto vacío: se
    // trata como "quitar" solo si ya había una).
    if (!mounted) return;
    if (url == null && _epgUrl == null) return;
    await widget.data.setEpgUrlSetting(url);
    if (mounted) setState(() => _epgUrl = url);
  }

  Future<void> _editCameraUrl() async {
    final url = await showTvTextPrompt(
      context,
      title: 'Cámara de seguridad',
      label: 'Dirección RTSP; vacío para quitarla',
      initial: _cameraUrl ?? '',
    );
    // Igual que la guía: `null` es cancelar, o quitar si ya había una.
    if (!mounted) return;
    if (url == null && _cameraUrl == null) return;
    await widget.data.setCameraUrlSetting(url);
    if (!mounted) return;
    setState(() => _cameraUrl = url);
    _setMessage(url == null
        ? 'Cámara quitada'
        : 'Cámara guardada: búscala como canal «Cámara» en Favoritos');
  }

  Future<void> _toggleZeroCopy() async {
    final next = !_zeroCopy;
    await widget.data.setMpvZeroCopySetting(next);
    if (mounted) setState(() => _zeroCopy = next);
  }

  Future<void> _toggleHideDead() async {
    final next = !_hideDead;
    await widget.data.setHideDeadSetting(next);
    if (mounted) setState(() => _hideDead = next);
  }

  Future<void> _clearDead() async {
    if (_deadCount == 0) return;
    final ok = await showTvConfirm(
      context,
      message: '¿Limpiar las marcas de canales caídos?',
      confirmLabel: 'Limpiar',
    );
    if (!ok) return;
    await widget.data.clearDeadChannels();
    if (mounted) setState(() => _deadCount = 0);
  }

  Future<void> _toggleContrast() async {
    final next = !_highContrast;
    await widget.data.setHighContrastSetting(next);
    if (mounted) setState(() => _highContrast = next);
    TvAppearance.applyHighContrast(next);
  }

  Future<void> _toggleEngine() async {
    final mode = _engineMode.next;
    await widget.data.setVideoEngineMode(mode);
    if (mounted) setState(() => _engineMode = mode);
  }

  Future<void> _openSourceMenu(_SourceEntry entry) async {
    final s = entry.source;
    final choice = await showTvOptions<String>(
      context,
      title: s.name,
      options: [
        if (SourceRefresher.isRefreshable(s)) ('Actualizar', 'refresh'),
        (s.enabled ? 'Desactivar' : 'Activar', 'toggle'),
        ('Eliminar', 'delete'),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'refresh':
        await _refreshNow(onlySourceId: s.id);
      case 'toggle':
        await widget.data.setSourceEnabled(s.id!, !s.enabled);
        if (mounted) _load();
      case 'delete':
        final confirmed = await showTvConfirm(
          context,
          message: '¿Eliminar la fuente «${s.name}» y sus canales?',
        );
        if (!mounted || !confirmed) return;
        await widget.data.deleteSource(s.id!);
        if (!mounted) return;
        await _load();
        _topNode.requestFocus();
    }
  }

  String _subtitle(_SourceEntry e) {
    if (!e.source.enabled) return 'Desactivada';
    final last = e.lastRefresh;
    if (last == null) return 'Nunca actualizada';
    return 'Actualizada ${formatAgo(DateTime.now().difference(last))}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(children: [
          // El estado va fijo arriba: con tantas filas quedaba fuera de pantalla.
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: TvTheme.fontBody,
                  color: _messageIsError ? TvTheme.error : TvTheme.success,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-iptv'),
                    focusNode: _topNode,
                    icon: Icons.public,
                    title: 'Agregar desde iptv-org',
                    onSelect: () => _open(TvIptvOrgScreen(data: widget.data)),
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-m3u'),
                    icon: Icons.link,
                    title: 'Agregar lista M3U por URL',
                    onSelect: () => _open(TvAddM3uScreen(data: widget.data)),
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-refresh'),
                    icon: Icons.refresh,
                    title: 'Actualizar listas ahora',
                    onSelect: _refreshNow,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-auto'),
                    icon: Icons.autorenew,
                    title: 'Actualización automática (cada 24 h)',
                    trailing: Text(
                      _autoRefresh ? 'Activada' : 'Desactivada',
                      style: TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: _autoRefresh
                            ? TvTheme.success
                            : TvTheme.textSecondary,
                      ),
                    ),
                    onSelect: _toggleAuto,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-buffer'),
                    icon: Icons.speed,
                    title: 'Buffer de reproducción',
                    subtitle:
                        'Más segundos = menos tirones; empieza algo más tarde',
                    trailing: Text(
                      TvBuffer.label(_bufferSecs),
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _cycleBuffer,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-engine'),
                    icon: Icons.memory,
                    title: 'Motor de video',
                    subtitle: _engineMode == TvEngineMode.auto
                        ? 'ExoPlayer y, si falla, mpv'
                        : 'Solo mpv (el más compatible)',
                    trailing: Text(
                      _engineMode.label,
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _toggleEngine,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-zerocopy'),
                    icon: Icons.speed,
                    title: 'Decodificación de video (mpv)',
                    subtitle: _zeroCopy
                        ? 'Experimental: sin copiar fotogramas; si no da imagen, vuelve a la automática'
                        : 'Si un canal 1080p va a tirones con mpv, prueba "Sin copia"',
                    trailing: Text(
                      _zeroCopy ? 'Sin copia' : 'Automática',
                      style: TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: _zeroCopy ? TvTheme.favorite : TvTheme.accent,
                      ),
                    ),
                    onSelect: _toggleZeroCopy,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-textsize'),
                    icon: Icons.format_size,
                    title: 'Tamaño de letra',
                    subtitle: 'Agranda los textos de toda la interfaz',
                    trailing: Text(
                      TvAppearance.scaleLabel(_textScale),
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _cycleTextScale,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-contrast'),
                    icon: Icons.contrast,
                    title: 'Alto contraste',
                    subtitle:
                        'Texto más claro y borde de foco amarillo más grueso',
                    trailing: Text(
                      _highContrast ? 'Activado' : 'Desactivado',
                      style: TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: _highContrast
                            ? TvTheme.success
                            : TvTheme.textSecondary,
                      ),
                    ),
                    onSelect: _toggleContrast,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-hidedead'),
                    icon: Icons.visibility_off,
                    title: 'Ocultar canales caídos',
                    subtitle:
                        'En Canales y Búsqueda (Favoritos siempre los muestra)',
                    trailing: Text(
                      _hideDead ? 'Activado' : 'Desactivado',
                      style: TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color:
                            _hideDead ? TvTheme.success : TvTheme.textSecondary,
                      ),
                    ),
                    onSelect: _toggleHideDead,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-deadcount'),
                    icon: Icons.link_off,
                    title: 'Canales caídos',
                    subtitle:
                        'Se saltan al cambiar de canal. OK para limpiar las marcas',
                    trailing: Text(
                      _deadCount == 0 ? 'Ninguno' : '$_deadCount marcados',
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _clearDead,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-hideadult'),
                    icon: Icons.child_care,
                    title: 'Ocultar contenido adulto',
                    subtitle: _hasPin
                        ? 'Desactivarlo exige el PIN'
                        : 'Crea un PIN para protegerlo',
                    trailing: Text(
                      _hideAdult ? 'Activado' : 'Desactivado',
                      style: TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: _hideAdult
                            ? TvTheme.success
                            : TvTheme.textSecondary,
                      ),
                    ),
                    onSelect: _toggleHideAdult,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-pin'),
                    icon: Icons.lock,
                    title: 'PIN de control parental',
                    subtitle: 'De 4 dígitos; protege el filtro de adultos',
                    trailing: Text(
                      _hasPin ? 'Configurado' : 'Sin PIN',
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _managePin,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-backup'),
                    icon: Icons.save_alt,
                    title: 'Copia de seguridad',
                    subtitle:
                        'Exporta o importa favoritos, listas propias y ajustes',
                    onSelect: _backupMenu,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-epgurl'),
                    icon: Icons.calendar_month,
                    title: 'Guía personalizada (XMLTV)',
                    subtitle:
                        'Más canales con guía; se suma a la de tus países',
                    trailing: Text(
                      _epgUrl == null ? 'Sin definir' : 'Definida',
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _editEpgUrl,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-camera'),
                    icon: Icons.videocam,
                    title: 'Cámara de seguridad',
                    subtitle:
                        'Se ve como canal y en un recuadro (mantén OK en un canal)',
                    trailing: Text(
                      _cameraUrl == null ? 'Sin cámara' : 'Configurada',
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _editCameraUrl,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
                  child: Text(
                    'Mis fuentes',
                    style: TextStyle(
                      fontSize: TvTheme.fontTitle,
                      fontWeight: FontWeight.bold,
                      color: TvTheme.textPrimary,
                    ),
                  ),
                ),
                for (final entry in _entries)
                  _gap(
                    TvListRow(
                      key: ValueKey('tv-source-${entry.source.id}'),
                      icon: Icons.playlist_play,
                      title: entry.source.name,
                      subtitle: _subtitle(entry),
                      onSelect: () => _openSourceMenu(entry),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _gap(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: child);
}
