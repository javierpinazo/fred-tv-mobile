import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/iptv_org_catalog.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/tv_source_errors.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_list_row.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

const _sectionTitles = ['Recomendados', 'Países', 'Categorías'];
const _sectionIcons = [Icons.star_outline, Icons.public, Icons.category_outlined];
const double _itemExtent = 72;

/// Catálogo de listas automáticas de iptv-org.
class TvIptvOrgScreen extends StatefulWidget {
  const TvIptvOrgScreen({super.key, required this.data});

  final TvData data;

  @override
  State<TvIptvOrgScreen> createState() => _TvIptvOrgScreenState();
}

class _TvIptvOrgScreenState extends State<TvIptvOrgScreen> {
  int _section = 0;
  final Map<int, List<IptvOrgPlaylist>> _lists = {
    0: IptvOrgCatalog.recommended,
  };
  final Set<int> _loading = {};
  final Set<int> _failed = {};
  Set<String> _addedUrls = {};
  bool _busy = false;

  final List<FocusNode> _sectionNodes = List.generate(3, (_) => FocusNode());
  final Map<int, FocusNode> _itemNodes = {};
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAdded();
  }

  @override
  void dispose() {
    for (final n in _sectionNodes) {
      n.dispose();
    }
    for (final n in _itemNodes.values) {
      n.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  FocusNode _itemNode(int i) => _itemNodes.putIfAbsent(i, FocusNode.new);

  Future<void> _loadAdded() async {
    try {
      final sources = await widget.data.sources();
      if (!mounted) return;
      setState(() => _addedUrls =
          sources.map((s) => (s.url ?? '').toLowerCase()).toSet());
    } catch (e) {
      debugPrint('TvIptvOrgScreen: error leyendo fuentes: $e');
    }
  }

  Future<void> _showSection(int index) async {
    if (_section != index) setState(() => _section = index);
    if (_lists.containsKey(index) || _loading.contains(index)) return;
    setState(() {
      _loading.add(index);
      _failed.remove(index);
    });
    try {
      final list = index == 1
          ? await widget.data.catalog.countries()
          : await widget.data.catalog.categories();
      if (!mounted) return;
      setState(() {
        _lists[index] = list;
        _loading.remove(index);
      });
    } catch (e) {
      debugPrint('TvIptvOrgScreen: error cargando catálogo: $e');
      if (!mounted) return;
      setState(() {
        _failed.add(index);
        _loading.remove(index);
      });
    }
  }

  void _focusFirstItem() {
    final node = _itemNode(0);
    if (node.context != null) {
      node.requestFocus();
      return;
    }
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _itemNode(0).requestFocus();
    });
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _add(IptvOrgPlaylist playlist) async {
    if (_busy) return;
    if (_addedUrls.contains(playlist.url.toLowerCase())) {
      _toast('Ya agregada');
      return;
    }
    _busy = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: TvTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(
                  'Agregando «${playlist.name}»…',
                  style: const TextStyle(
                    fontSize: TvTheme.fontBody,
                    color: TvTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    String message;
    try {
      await widget.data.addSource(Source(
        name: playlist.sourceName,
        url: playlist.url,
        sourceType: SourceType.m3uUrl,
        enabled: true,
      ));
      message = '«${playlist.name}» agregada';
    } catch (e) {
      debugPrint('TvIptvOrgScreen: error agregando "${playlist.name}": $e');
      message = tvAddSourceErrorMessage(e);
    }
    _busy = false;
    if (!mounted) return;
    Navigator.of(context).pop(); // cierra el diálogo de progreso
    await _loadAdded();
    if (mounted) _toast(message);
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
            const Text(
              'Listas de iptv-org',
              style: TextStyle(
                fontSize: TvTheme.fontTitle,
                fontWeight: FontWeight.bold,
                color: TvTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 260, child: _buildSections()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildItems()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSections() {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            (_lists[_section]?.isNotEmpty ?? false)) {
          _focusFirstItem();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          for (var i = 0; i < _sectionTitles.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TvListRow(
                key: ValueKey('tv-iptv-section-$i'),
                focusNode: _sectionNodes[i],
                autofocus: i == 0,
                icon: _sectionIcons[i],
                title: _sectionTitles[i],
                onFocusChange: (focused) {
                  if (focused) _showSection(i);
                },
                onSelect: _focusFirstItem,
                trailing: i == _section
                    ? const Icon(Icons.chevron_right,
                        color: TvTheme.accent, size: 26)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItems() {
    if (_loading.contains(_section)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed.contains(_section)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No se pudo cargar el catálogo. Revisa tu conexión.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: TvTheme.fontBody,
                color: TvTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: TvListRow(
                key: const ValueKey('tv-iptv-retry'),
                title: 'Reintentar',
                icon: Icons.refresh,
                onSelect: () {
                  setState(() => _failed.remove(_section));
                  _showSection(_section);
                },
              ),
            ),
          ],
        ),
      );
    }
    final items = _lists[_section] ?? const <IptvOrgPlaylist>[];
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _sectionNodes[_section].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListView.builder(
        controller: _scroll,
        itemCount: items.length,
        itemExtent: _itemExtent,
        itemBuilder: (context, index) {
          final p = items[index];
          final added = _addedUrls.contains(p.url.toLowerCase());
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TvListRow(
              key: ValueKey('tv-iptv-item-$index'),
              focusNode: _itemNode(index),
              leading: p.flag == null
                  ? null
                  : Text(p.flag!, style: const TextStyle(fontSize: 28)),
              icon: p.flag == null ? Icons.live_tv : null,
              title: p.name,
              subtitle: p.kind == IptvOrgKind.language ? 'Idioma' : null,
              trailing: added
                  ? const Text(
                      'Agregada',
                      style: TextStyle(
                        fontSize: TvTheme.fontSmall,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.success,
                      ),
                    )
                  : null,
              onSelect: () => _add(p),
            ),
          );
        },
      ),
    );
  }
}
