import 'package:flutter/material.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Botón de TV único (diálogos, errores, arranque). Con foco invierte los
/// colores (fondo claro, texto oscuro) para que se distinga a 3 metros.
class TvButton extends StatelessWidget {
  const TvButton({
    super.key,
    required this.label,
    required this.onSelect,
    this.primary = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback onSelect;

  /// Acción principal: fondo de acento cuando no tiene el foco.
  final bool primary;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onSelect: onSelect,
      builder: (context, focused) => Container(
        constraints: const BoxConstraints(minWidth: 160, minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused
              ? TvTheme.focusBorder
              : (primary ? TvTheme.accent : TvTheme.surface),
          borderRadius: BorderRadius.circular(TvTheme.radius - 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: TvTheme.fontBody,
            color: focused ? TvTheme.background : TvTheme.textPrimary,
            fontWeight: focused ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
