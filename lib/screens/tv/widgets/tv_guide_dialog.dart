import 'package:flutter/material.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Días hacia adelante que se pueden consultar (el sitio publica una semana).
const int _maxDaysAhead = 6;

const List<String> _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// Programación de un canal por día. [clock] permite fijar "ahora" en pruebas.
Future<void> showTvGuide(
  BuildContext context, {
  required TvData data,
  required Channel channel,
  DateTime Function()? clock,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _GuideDialog(data: data, channel: channel, clock: clock),
  );
}

class _GuideDialog extends StatefulWidget {
  const _GuideDialog({required this.data, required this.channel, this.clock});

  final TvData data;
  final Channel channel;
  final DateTime Function()? clock;

  @override
  State<_GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<_GuideDialog> {
  late final DateTime _today;
  int _offset = 0;
  int _request = 0;
  bool _loading = true;
  bool _failed = false;
  List<GuideProgram> _programs = const [];
  List<FocusNode> _nodes = [];

  DateTime _now() => (widget.clock ?? DateTime.now)().toUtc();

  DateTime get _day => DateTime(_today.year, _today.month, _today.day + _offset);

  @override
  void initState() {
    super.initState();
    _today = limaDay(_now());
    _load();
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final programs = await widget.data.guideDay(widget.channel, _day);
      if (!mounted || request != _request) return;
      _swapNodes(programs.length);
      setState(() {
        _programs = programs;
        _loading = false;
      });
      _focusInitial(programs);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _programs = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  void _swapNodes(int count) {
    final old = _nodes;
    _nodes = List.generate(count, (_) => FocusNode());
    // Se liberan tras el siguiente fotograma: aún los usan los widgets viejos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final n in old) {
        n.dispose();
      }
    });
  }

  /// Lleva el foco al programa en emisión (hoy) o al primero.
  void _focusInitial(List<GuideProgram> programs) {
    if (programs.isEmpty) return;
    var index = 0;
    if (_offset == 0) {
      final now = guideNowNext(programs, _now()).now;
      if (now != null) index = programs.indexOf(now);
    }
    final node = _nodes[index];
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted && node.context != null) node.requestFocus();
    });
  }

  void _goTo(int offset) {
    if (offset < 0 || offset > _maxDaysAhead || offset == _offset) return;
    _offset = offset;
    _load();
  }

  String _dayLabel() {
    if (_offset == 0) return 'Hoy';
    if (_offset == 1) return 'Mañana';
    final d = _day;
    return '${_weekdays[d.weekday - 1]} '
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  Widget _navButton(String label, IconData icon, Key key, VoidCallback onSelect,
      {bool enabled = true}) {
    return TvFocusable(
      key: key,
      scaleOnFocus: false,
      onSelect: onSelect,
      builder: (context, focused) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
          borderRadius: BorderRadius.circular(TvTheme.radius - 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: enabled ? TvTheme.textPrimary : TvTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: TvTheme.fontBody,
                color: enabled ? TvTheme.textPrimary : TvTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int i, GuideProgram p, bool isNow) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TvFocusable(
        key: ValueKey('tv-guide-item-$i'),
        focusNode: _nodes[i],
        scaleOnFocus: false,
        builder: (context, focused) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: focused ? TvTheme.surfaceRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(TvTheme.radius - 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  p.timeLabel,
                  style: TextStyle(
                    fontSize: TvTheme.fontBody,
                    fontWeight: FontWeight.bold,
                    color: isNow ? TvTheme.accent : TvTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: TvTheme.fontBody,
                        color: TvTheme.textPrimary,
                      ),
                    ),
                    if (p.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          p.description!,
                          maxLines: focused ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: TvTheme.fontSmall,
                            color: TvTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isNow)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TvTheme.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AHORA',
                    style: TextStyle(
                      fontSize: TvTheme.fontSmall,
                      fontWeight: FontWeight.bold,
                      color: TvTheme.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No se pudo cargar la guía',
              style: TextStyle(
                fontSize: TvTheme.fontBody,
                color: TvTheme.error,
              ),
            ),
          ),
          _navButton('Reintentar', Icons.refresh,
              const ValueKey('tv-guide-retry'), _load),
        ],
      );
    }
    if (_programs.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Sin programación para este día',
            style: TextStyle(
              fontSize: TvTheme.fontBody,
              color: TvTheme.textSecondary,
            ),
          ),
        ),
      );
    }
    final now = _offset == 0 ? guideNowNext(_programs, _now()).now : null;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _programs.length,
      itemBuilder: (context, i) =>
          _row(i, _programs[i], identical(_programs[i], now)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TvTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: TvTheme.fontTitle,
                  fontWeight: FontWeight.bold,
                  color: TvTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _navButton('Anterior', Icons.chevron_left,
                      const ValueKey('tv-guide-prev'), () => _goTo(_offset - 1),
                      enabled: _offset > 0),
                  Expanded(
                    child: Center(
                      child: Text(
                        _dayLabel(),
                        style: const TextStyle(
                          fontSize: TvTheme.fontTitle,
                          color: TvTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  _navButton('Siguiente', Icons.chevron_right,
                      const ValueKey('tv-guide-next'), () => _goTo(_offset + 1),
                      enabled: _offset < _maxDaysAhead),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(child: _body()),
            ],
          ),
        ),
      ),
    );
  }
}
