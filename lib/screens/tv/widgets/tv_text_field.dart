import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_keyboard.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Campo de texto apto para D-pad. Por defecto se comporta como un botón
/// (enfocarlo no abre el teclado); OK entra en modo edición y ↑/↓ salen.
class TvTextField extends StatefulWidget {
  const TvTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  FocusNode? _ownButtonNode;
  final FocusNode _fieldNode = FocusNode();
  bool _editing = false;
  bool _hasEdited = false;

  FocusNode get _buttonNode =>
      widget.focusNode ?? (_ownButtonNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _fieldNode.addListener(_onFieldFocus);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _fieldNode.removeListener(_onFieldFocus);
    _fieldNode.dispose();
    _ownButtonNode?.dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted && !_editing) setState(() {});
  }

  void _onFieldFocus() {
    // El foco se fue a otro sitio (p. ej. Atrás al menú): se sale de edición
    // sin volver a pedir el foco para no quitárselo a quien lo tiene.
    if (_editing && !_fieldNode.hasFocus) _exitEditing(refocus: false);
  }

  /// OK abre el teclado propio (navegable con el D-pad). "Voz / sistema" pasa
  /// al teclado de Android con el texto ya escrito.
  Future<void> _openKeyboard() async {
    final result = await showTvKeyboard(
      context,
      label: widget.label,
      initial: widget.controller.text,
      doneLabel:
          widget.textInputAction == TextInputAction.search ? 'Buscar' : 'Listo',
    );
    if (!mounted || result == null) return;
    widget.controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.text.length),
    );
    if (result.useSystem) {
      _startEditing();
      return;
    }
    widget.onChanged?.call(result.text);
    widget.onSubmitted?.call(result.text);
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _hasEdited = true;
    });
    // `autofocus` no es fiable dentro de un FocusScope anidado: se pide el
    // foco de forma explícita cuando el TextField ya está montado.
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted && _editing) _fieldNode.requestFocus();
    });
  }

  /// Sale del modo edición y devuelve el foco al modo botón; si se indica
  /// [then], continúa moviendo el foco en esa dirección.
  void _exitEditing({TraversalDirection? then, bool refocus = true}) {
    if (!_editing) return;
    setState(() => _editing = false);
    if (!refocus) return;
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (!mounted) return;
      _buttonNode.requestFocus();
      if (then != null) _buttonNode.focusInDirection(then);
    });
  }

  KeyEventResult _onEditingKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;
      // ↑ sale del modo edición.
      if (key == LogicalKeyboardKey.arrowUp) {
        _exitEditing(then: TraversalDirection.up);
        return KeyEventResult.handled;
      }
      // ↓ ← → son para navegar el teclado en pantalla de Android TV: se
      // devuelven a la plataforma sin marcarlos como manejados (si no, el
      // TextField los usa para mover el cursor y el teclado nunca los recibe).
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        return KeyEventResult.skipRemainingHandlers;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) return _buildEditor();
    return TvFocusable(
      focusNode: _buttonNode,
      autofocus: widget.autofocus && !_hasEdited,
      onSelect: _openKeyboard,
      scaleOnFocus: false,
      builder: (context, focused) {
        final text = widget.controller.text;
        return _frame(
          focused: focused,
          child: Text(
            text.isEmpty ? (widget.hint ?? '') : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: TvTheme.fontBody,
              color: text.isEmpty
                  ? TvTheme.textSecondary
                  : TvTheme.textPrimary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditor() {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onEditingKey,
      child: _frame(
        focused: true,
        child: TextField(
          controller: widget.controller,
          focusNode: _fieldNode,
          autofocus: true,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onSubmitted: (value) {
            _exitEditing();
            widget.onSubmitted?.call(value);
          },
          style: const TextStyle(
            fontSize: TvTheme.fontBody,
            color: TvTheme.textPrimary,
          ),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _frame({required bool focused, required Widget child}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
        borderRadius: BorderRadius.circular(TvTheme.radius - 2),
        border: _editing
            ? Border.all(color: TvTheme.accent, width: TvTheme.focusBorderWidth)
            : null,
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: TvTheme.textSecondary, size: 28),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: TvTheme.fontSmall,
                    color: TvTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
