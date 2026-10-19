import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Resultado del teclado en pantalla de TV.
class TvKeyboardResult {
  const TvKeyboardResult.text(this.text) : useSystem = false;

  /// El usuario pidió el teclado del sistema (voz, etc.); [text] es lo escrito.
  const TvKeyboardResult.system(this.text) : useSystem = true;

  final String text;
  final bool useSystem;
}

/// Teclado propio navegable con el D-pad. El teclado de sistema de muchos
/// Android TV no recibe las flechas del control, por eso la app trae el suyo.
///
/// Devuelve `null` si se cancela con Atrás.
Future<TvKeyboardResult?> showTvKeyboard(
  BuildContext context, {
  required String label,
  String initial = '',
  String doneLabel = 'Listo',
  bool offerSystemKeyboard = true,
}) async {
  final navigator = Navigator.of(context);
  final route = DialogRoute<TvKeyboardResult>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (_) => _TvKeyboardDialog(
      label: label,
      initial: initial,
      doneLabel: doneLabel,
      offerSystemKeyboard: offerSystemKeyboard,
    ),
  );
  final result = await navigator.push(route);
  // El resultado se entrega cuando el diálogo ya terminó de cerrarse y el foco
  // volvió a la pantalla de origen (quien lo recibe puede mover el foco).
  await route.completed;
  return result;
}

const List<String> _charRows = [
  '1234567890',
  'qwertyuiop',
  'asdfghjklñ',
  'zxcvbnm.-_',
];

const double _unit = 64;
const double _keyHeight = 48;
const double _gap = 6;

class _TvKeyboardDialog extends StatefulWidget {
  const _TvKeyboardDialog({
    required this.label,
    required this.initial,
    required this.doneLabel,
    required this.offerSystemKeyboard,
  });

  final String label;
  final String initial;
  final String doneLabel;
  final bool offerSystemKeyboard;

  @override
  State<_TvKeyboardDialog> createState() => _TvKeyboardDialogState();
}

class _TvKeyboardDialogState extends State<_TvKeyboardDialog> {
  late String _text = widget.initial;
  bool _shift = false;

  void _append(String ch) =>
      setState(() => _text += _shift ? ch.toUpperCase() : ch);

  void _backspace() {
    if (_text.isEmpty) return;
    setState(() => _text = _text.substring(0, _text.length - 1));
  }

  void _done() => Navigator.of(context).pop(TvKeyboardResult.text(_text));

  KeyEventResult _onPhysicalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final c = event.character;
    if (c != null && c.isNotEmpty && c.codeUnitAt(0) >= 32 &&
        c.codeUnitAt(0) != 127) {
      setState(() => _text += c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _key(
    String id,
    String label, {
    required VoidCallback onPress,
    double units = 1,
    bool active = false,
    bool filled = false,
    bool autofocus = false,
  }) {
    final width = units * _unit + (units - 1) * _gap;
    return Padding(
      padding: const EdgeInsets.all(_gap / 2),
      child: SizedBox(
        width: width,
        height: _keyHeight,
        child: TvFocusable(
          key: ValueKey('tv-key-$id'),
          autofocus: autofocus,
          scaleOnFocus: false,
          onSelect: onPress,
          builder: (context, focused) => Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled || active
                  ? TvTheme.accent
                  : (focused ? TvTheme.surfaceRaised : const Color(0xFF24242C)),
              borderRadius: BorderRadius.circular(TvTheme.radius - 2),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: TvTheme.fontBody,
                color: TvTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _charKey(String ch) => _key(
        ch,
        _shift ? ch.toUpperCase() : ch,
        onPress: () => _append(ch),
        autofocus: ch == 'q',
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.bottomCenter,
      backgroundColor: TvTheme.surface,
      insetPadding: const EdgeInsets.fromLTRB(48, 16, 48, 27),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onPhysicalKey,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPreview(),
              const SizedBox(height: 8),
              for (final row in _charRows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final ch in row.split('')) _charKey(ch)],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _key('shift', 'Mayús',
                      units: 2, active: _shift, onPress: () {
                    setState(() => _shift = !_shift);
                  }),
                  _key(':', ':', onPress: () => _append(':')),
                  _key('/', '/', onPress: () => _append('/')),
                  _key('@', '@', onPress: () => _append('@')),
                  _key('space', 'Espacio', units: 4, onPress: () => _append(' ')),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _key('back', '⌫ Borrar', units: 2, onPress: _backspace),
                  _key('clear', 'Limpiar', units: 2,
                      onPress: () => setState(() => _text = '')),
                  if (widget.offerSystemKeyboard)
                    _key('system', 'Voz / sistema', units: 3, onPress: () {
                      Navigator.of(context).pop(TvKeyboardResult.system(_text));
                    }),
                  _key('done', widget.doneLabel,
                      units: widget.offerSystemKeyboard ? 3 : 6,
                      filled: true,
                      onPress: _done),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      width: 10 * _unit + 9 * _gap + 10 * _gap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: TvTheme.background,
        borderRadius: BorderRadius.circular(TvTheme.radius - 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: TvTheme.fontSmall,
              color: TvTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: Text(
                  _text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: TvTheme.fontTitle,
                    color: TvTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 2,
                height: 28,
                margin: const EdgeInsets.only(left: 2),
                color: TvTheme.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
