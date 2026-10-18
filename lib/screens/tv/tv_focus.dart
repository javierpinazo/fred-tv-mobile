import 'package:flutter/widgets.dart';

/// Acción direccional que avisa cuando no hay más elementos en esa dirección
/// dentro del scope actual (p. ej. para saltar al menú lateral).
class TvEdgeFocusAction extends DirectionalFocusAction {
  TvEdgeFocusAction({required this.onEdge});

  final void Function(TraversalDirection direction) onEdge;

  @override
  void invoke(DirectionalFocusIntent intent) {
    final moved = primaryFocus?.focusInDirection(intent.direction) ?? false;
    if (!moved) onEdge(intent.direction);
  }
}

/// Enfoca el último hijo enfocado del [scope] o, si nunca tuvo foco, el
/// primero. Devuelve `false` (sin mover el foco) si el scope no tiene
/// elementos enfocables.
bool focusFirstIn(FocusScopeNode scope) {
  final context = scope.context;
  if (context == null) return false;
  final target = FocusTraversalGroup.maybeOf(context)?.findFirstFocus(scope);
  if (target == null || target == scope) return false;
  target.requestFocus();
  return true;
}
