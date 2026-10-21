import 'package:flutter/material.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/backend/sql.dart' show customSourceName;
import 'package:open_tv/models/source.dart';
import 'package:open_tv/screens/tv/player/tv_buffer.dart';
import 'package:open_tv/screens/tv/player/tv_camera.dart' show tvCameraChannelName;
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
  String? _language;
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
      final language = await widget.data.languageSetting();
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
        _language = language;
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
    final l10n = context.l10n;
    if (widget.data.isRefreshing) {
      _setMessage(l10n.settingsAlreadyRefreshing);
      return;
    }
    _setMessage(l10n.settingsRefreshing);
    try {
      final result =
          await widget.data.refreshSources(onlySourceId: onlySourceId);
      if (result.failedNames.isNotEmpty) {
        _setMessage(l10n.settingsRefreshFailedSome(result.failedNames.length),
            error: true);
      } else {
        _setMessage(l10n.settingsRefreshDone);
      }
    } catch (e) {
      debugPrint('TVSettings: error actualizando: $e');
      _setMessage(l10n.settingsRefreshFailed, error: true);
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
    _setMessage(context.l10n.pinWrong, error: true);
    return false;
  }

  /// Pide un PIN nuevo dos veces; `null` si se cancela o no coinciden.
  Future<String?> _askNewPin() async {
    final first =
        await showTvPinPrompt(context, title: context.l10n.pinNew);
    if (first == null || !mounted) return null;
    final second =
        await showTvPinPrompt(context, title: context.l10n.pinRepeat);
    if (second == null || !mounted) return null;
    if (first != second) {
      _setMessage(context.l10n.pinMismatch, error: true);
      return null;
    }
    return first;
  }

  Future<void> _toggleHideAdult() async {
    final next = !_hideAdult;
    // Activar es libre; desactivar exige el PIN si hay uno.
    if (!next && _hasPin && !await _verifyPin(context.l10n.pinEnter)) {
      return;
    }
    await widget.data.setHideAdultSetting(next);
    if (mounted) setState(() => _hideAdult = next);
  }

  Future<void> _managePin() async {
    if (!_hasPin) {
      final pin = await _askNewPin();
      if (pin == null) return;
      await widget.data.setParentalPin(pin);
      if (mounted) setState(() => _hasPin = true);
      _setMessage(context.l10n.pinSaved);
      return;
    }
    if (!await _verifyPin(context.l10n.pinEnterCurrent)) return;
    final choice = await showTvOptions<int>(
      context,
      title: context.l10n.settingsPin,
      options: [(context.l10n.pinChange, 0), (context.l10n.pinRemove, 1)],
    );
    if (choice == null || !mounted) return;
    if (choice == 1) {
      await widget.data.setParentalPin(null);
      if (mounted) setState(() => _hasPin = false);
      _setMessage(context.l10n.pinRemoved);
      return;
    }
    final pin = await _askNewPin();
    if (pin == null) return;
    await widget.data.setParentalPin(pin);
    _setMessage(context.l10n.pinSaved);
  }

  static String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

  Future<void> _backupMenu() async {
    final choice = await showTvOptions<String>(
      context,
      title: context.l10n.settingsBackup,
      options: [
        (context.l10n.backupExport, 'export'),
        (context.l10n.backupImportMenu, 'import'),
      ],
    );
    if (choice == 'export') await _exportBackup();
    if (choice == 'import') await _importBackupMenu();
  }

  Future<void> _exportBackup() async {
    try {
      final path = await widget.data.exportBackupToFile();
      _setMessage(context.l10n.backupSavedTo(path));
    } catch (e) {
      debugPrint('TVSettings: error exportando: $e');
      _setMessage(context.l10n.backupSaveFailed, error: true);
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
      title: context.l10n.backupImportTitle,
      options: [
        for (final f in files) (_fileName(f), 'file:$f'),
        (context.l10n.backupFromUrl, 'url'),
        (context.l10n.backupFromPicker, 'picker'),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice.startsWith('file:')) {
      await _runImport(
          () => widget.data.importBackupFromFile(choice.substring(5)));
    } else if (choice == 'url') {
      final url = await showTvTextPrompt(
        context,
        title: context.l10n.backupImportFromUrlTitle,
        label: context.l10n.backupUrlLabel,
        confirmLabel: context.l10n.backupImportConfirm,
      );
      if (url == null || !mounted) return;
      await _runImport(() => widget.data.importBackupFromUrl(url));
    } else {
      final path = await widget.data.pickBackupFile();
      if (path == null || !mounted) {
        _setMessage(context.l10n.backupNoFile, error: true);
        return;
      }
      await _runImport(() => widget.data.importBackupFromFile(path));
    }
  }

  Future<void> _runImport(Future<BackupResult> Function() run) async {
    final l10n = context.l10n;
    _setMessage(l10n.backupImporting);
    try {
      final result = await run();
      _setMessage(l10n.backupImported(result.summary(l10n)));
    } on BackupFormatException catch (e) {
      _setMessage(e.localized(l10n), error: true);
    } catch (e) {
      debugPrint('TVSettings: error importando: $e');
      _setMessage(l10n.backupImportFailed, error: true);
    }
    if (mounted) _load();
  }

  Future<void> _editEpgUrl() async {
    final url = await showTvTextPrompt(
      context,
      title: context.l10n.settingsEpg,
      label: context.l10n.epgUrlLabel,
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
      title: context.l10n.settingsCamera,
      label: context.l10n.cameraUrlLabel,
      initial: _cameraUrl ?? '',
    );
    // Igual que la guía: `null` es cancelar, o quitar si ya había una.
    if (!mounted) return;
    if (url == null && _cameraUrl == null) return;
    await widget.data.setCameraUrlSetting(url);
    if (!mounted) return;
    setState(() => _cameraUrl = url);
    _setMessage(url == null
        ? context.l10n.cameraRemoved
        : context.l10n.cameraSaved(tvCameraChannelName));
  }

  Future<void> _pickLanguage() async {
    final choice = await showTvOptions<String>(
      context,
      title: context.l10n.settingsLanguage,
      options: [
        (context.l10n.settingsLanguageAuto, ''),
        for (final e in languageNativeNames.entries) (e.value, e.key),
      ],
    );
    if (choice == null || !mounted) return;
    final code = choice.isEmpty ? null : choice;
    await widget.data.setLanguageSetting(code);
    TvAppearance.locale.value = TvAppearance.parseLocale(code);
    if (mounted) setState(() => _language = code);
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
      message: context.l10n.deadClearConfirm,
      confirmLabel: context.l10n.deadClearAction,
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
        if (SourceRefresher.isRefreshable(s))
          (context.l10n.sourceRefresh, 'refresh'),
        (
          s.enabled ? context.l10n.sourceDisable : context.l10n.sourceEnable,
          'toggle'
        ),
        (context.l10n.commonDelete, 'delete'),
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
          message: context.l10n.sourceDeleteConfirm(s.name),
        );
        if (!mounted || !confirmed) return;
        await widget.data.deleteSource(s.id!);
        if (!mounted) return;
        await _load();
        _topNode.requestFocus();
    }
  }

  String _subtitle(_SourceEntry e, AppLocalizations l10n) {
    if (!e.source.enabled) return l10n.sourceDisabled;
    final last = e.lastRefresh;
    if (last == null) return l10n.sourceNeverRefreshed;
    return l10n.sourceRefreshedAgo(
        formatAgo(DateTime.now().difference(last), l10n));
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
                    title: context.l10n.settingsAddFromIptvOrg,
                    onSelect: () => _open(TvIptvOrgScreen(data: widget.data)),
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-m3u'),
                    icon: Icons.link,
                    title: context.l10n.settingsAddM3u,
                    onSelect: () => _open(TvAddM3uScreen(data: widget.data)),
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-refresh'),
                    icon: Icons.refresh,
                    title: context.l10n.settingsRefreshNow,
                    onSelect: _refreshNow,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-auto'),
                    icon: Icons.autorenew,
                    title: context.l10n.settingsAutoRefresh,
                    trailing: Text(
                      _autoRefresh
                          ? context.l10n.settingsAutoOn
                          : context.l10n.settingsAutoOff,
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
                    title: context.l10n.settingsBuffer,
                    subtitle: context.l10n.settingsBufferHint,
                    trailing: Text(
                      TvBuffer.label(_bufferSecs, context.l10n),
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
                    title: context.l10n.settingsEngine,
                    subtitle: _engineMode == TvEngineMode.auto
                        ? context.l10n.settingsEngineAutoHint
                        : context.l10n.settingsEngineMpvHint,
                    trailing: Text(
                      _engineMode.labelOf(context.l10n),
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
                    title: context.l10n.settingsDecoding,
                    subtitle: _zeroCopy
                        ? context.l10n.settingsDecodingZeroCopyHint
                        : context.l10n.settingsDecodingAutoHint,
                    trailing: Text(
                      _zeroCopy
                          ? context.l10n.settingsDecodingZeroCopy
                          : context.l10n.settingsDecodingAuto,
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
                    title: context.l10n.settingsTextSize,
                    subtitle: context.l10n.settingsTextSizeHint,
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
                    title: context.l10n.settingsHighContrast,
                    subtitle: context.l10n.settingsHighContrastHint,
                    trailing: Text(
                      _highContrast
                          ? context.l10n.commonOn
                          : context.l10n.commonOff,
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
                    title: context.l10n.settingsHideDead,
                    subtitle: context.l10n.settingsHideDeadHint,
                    trailing: Text(
                      _hideDead
                          ? context.l10n.commonOn
                          : context.l10n.commonOff,
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
                    title: context.l10n.settingsDeadChannels,
                    subtitle: context.l10n.settingsDeadChannelsHint,
                    trailing: Text(
                      _deadCount == 0
                          ? context.l10n.settingsDeadNone
                          : context.l10n.settingsDeadCount(_deadCount),
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
                    title: context.l10n.settingsHideAdult,
                    subtitle: _hasPin
                        ? context.l10n.settingsHideAdultHintPin
                        : context.l10n.settingsHideAdultHintNoPin,
                    trailing: Text(
                      _hideAdult
                          ? context.l10n.commonOn
                          : context.l10n.commonOff,
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
                    title: context.l10n.settingsPin,
                    subtitle: context.l10n.settingsPinHint,
                    trailing: Text(
                      _hasPin
                          ? context.l10n.settingsPinSet
                          : context.l10n.settingsPinNone,
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
                    title: context.l10n.settingsBackup,
                    subtitle: context.l10n.settingsBackupHint,
                    onSelect: _backupMenu,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-epgurl'),
                    icon: Icons.calendar_month,
                    title: context.l10n.settingsEpg,
                    subtitle: context.l10n.settingsEpgHint,
                    trailing: Text(
                      _epgUrl == null
                          ? context.l10n.settingsEpgUnset
                          : context.l10n.settingsEpgSet,
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
                    title: context.l10n.settingsCamera,
                    subtitle: context.l10n.settingsCameraHint,
                    trailing: Text(
                      _cameraUrl == null
                          ? context.l10n.settingsCameraUnset
                          : context.l10n.settingsCameraSet,
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _editCameraUrl,
                  ),
                ),
                _gap(
                  TvListRow(
                    key: const ValueKey('tv-settings-language'),
                    icon: Icons.language,
                    title: context.l10n.settingsLanguage,
                    subtitle: context.l10n.settingsLanguageHint,
                    trailing: Text(
                      _language == null
                          ? context.l10n.settingsLanguageAuto
                          : (languageNativeNames[_language] ?? _language!),
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.accent,
                      ),
                    ),
                    onSelect: _pickLanguage,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                  child: Text(
                    context.l10n.settingsMySources,
                    style: const TextStyle(
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
                      subtitle: _subtitle(entry, context.l10n),
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
