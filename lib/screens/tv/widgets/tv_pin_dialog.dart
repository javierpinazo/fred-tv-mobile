import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/screens/tv/player/tv_player_keys.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

const int _pinLength = 4;

/// Pide un PIN de 4 dígitos con un teclado numérico en pantalla (la mayoría de
/// los mandos de Android TV no tiene números); las teclas numéricas del mando o
/// del teclado también escriben. Devuelve el PIN, o `null` si se cancela.
Future<String?> showTvPinPrompt(
  BuildContext context, {
  required String title,
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PinDialog(title: title, subtitle: subtitle),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _pin = '';

  void _add(int digit) {
    if (_pin.length >= _pinLength) return;
    setState(() => _pin += '$digit');
    if (_pin.length == _pinLength) Navigator.of(context).pop(_pin);
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final digit = digitForKey(event.logicalKey);
    if (digit != null) {
      _add(digit);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _key(String label, Key key, VoidCallback onSelect,
      {bool autofocus = false, IconData? icon}) {
    return TvFocusable(
      key: key,
      autofocus: autofocus,
      scaleOnFocus: false,
      onSelect: onSelect,
      builder: (context, focused) => Container(
        width: 96,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? TvTheme.surfaceRaised : TvTheme.background,
          borderRadius: BorderRadius.circular(TvTheme.radius),
        ),
        child: icon != null
            ? Icon(icon, color: TvTheme.textPrimary)
            : Text(
                label,
                style: const TextStyle(
                  fontSize: TvTheme.fontTitle,
                  color: TvTheme.textPrimary,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                children[i],
              ],
            ],
          ),
        );
    return Focus(
      onKeyEvent: _onKey,
      child: Dialog(
        backgroundColor: TvTheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: TvTheme.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: TvTheme.textPrimary,
                  ),
                ),
                if (widget.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: TvTheme.fontBody,
                        color: TvTheme.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pinLength; i++)
                      Container(
                        key: ValueKey('tv-pin-dot-$i'),
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length
                              ? TvTheme.accent
                              : Colors.transparent,
                          border: Border.all(
                              color: TvTheme.textSecondary, width: 2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                row([for (final d in [1, 2, 3]) _digit(d)]),
                row([for (final d in [4, 5, 6]) _digit(d)]),
                row([for (final d in [7, 8, 9]) _digit(d)]),
                row([
                  _key('', const ValueKey('tv-pin-back'), _back,
                      icon: Icons.backspace_outlined),
                  _digit(0),
                  _key('Cancelar', const ValueKey('tv-pin-cancel'),
                      () => Navigator.of(context).pop()),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _digit(int d) => _key('$d', ValueKey('tv-pin-key-$d'), () => _add(d),
      autofocus: d == 5);
}
