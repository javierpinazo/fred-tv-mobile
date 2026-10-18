import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

final Set<LogicalKeyboardKey> _selectKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
};

final Set<LogicalKeyboardKey> _menuKeys = {
  LogicalKeyboardKey.contextMenu,
  LogicalKeyboardKey.info,
  LogicalKeyboardKey.f2,
};

/// Elemento enfocable común para TV: visual de foco, OK / OK largo / MENU y
/// auto-scroll. No consume flechas ni Atrás.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.builder,
    this.onSelect,
    this.onLongPress,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.scaleOnFocus = true,
    this.decorate = true,
    this.ensureVisibleOnFocus = true,
  });

  final Widget Function(BuildContext context, bool focused) builder;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool scaleOnFocus;
  final bool decorate;
  final bool ensureVisibleOnFocus;

  @override
  State<TvFocusable> createState() => TvFocusableState();
}

class TvFocusableState extends State<TvFocusable> {
  FocusNode? _ownNode;
  bool _focused = false;
  bool _pressed = false;
  bool _longFired = false;

  FocusNode get focusNode => widget.focusNode ?? (_ownNode ??= FocusNode());

  bool get hasFocus => _focused;

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    if (!mounted) return;
    setState(() => _focused = focused);
    if (!focused) {
      _pressed = false;
      _longFired = false;
    } else if (widget.ensureVisibleOnFocus) {
      if (Scrollable.maybeOf(context) != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: TvTheme.focusDuration,
        );
      }
    }
    widget.onFocusChange?.call(focused);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (_selectKeys.contains(key)) {
      if (widget.onSelect == null && widget.onLongPress == null) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent) {
        _pressed = true;
        _longFired = false;
        return KeyEventResult.handled;
      }
      if (event is KeyRepeatEvent) {
        if (_pressed && !_longFired && widget.onLongPress != null) {
          _longFired = true;
          widget.onLongPress!();
        }
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        if (!_pressed) return KeyEventResult.ignored;
        final fire = !_longFired;
        _pressed = false;
        _longFired = false;
        if (fire) widget.onSelect?.call();
        return KeyEventResult.handled;
      }
    }
    if (_menuKeys.contains(key) && widget.onLongPress != null) {
      if (event is KeyDownEvent) {
        widget.onLongPress!();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.builder(context, _focused);
    if (widget.decorate) {
      content = AnimatedContainer(
        duration: TvTheme.focusDuration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TvTheme.radius),
          border: Border.all(
            color: _focused ? TvTheme.focusBorder : Colors.transparent,
            width: TvTheme.focusBorderWidth,
          ),
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: content,
      );
    }
    if (widget.scaleOnFocus) {
      content = AnimatedScale(
        scale: _focused ? TvTheme.focusScale : 1.0,
        duration: TvTheme.focusDuration,
        child: content,
      );
    }
    return Focus(
      focusNode: focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKey,
      child: content,
    );
  }
}
