import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/tv_focus.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';

import 'fakes.dart';

Widget _tile(String id, {bool autofocus = false}) => TvFocusable(
      key: ValueKey(id),
      autofocus: autofocus,
      onSelect: () {},
      builder: (_, __) => const SizedBox(width: 100, height: 100),
    );

void main() {
  testWidgets('acción de borde y memoria del scope', (t) async {
    final edges = <TraversalDirection>[];
    final scope = FocusScopeNode();
    await pumpTv(
      t,
      Row(
        children: [
          FocusScope(child: _tile('side')),
          Actions(
            actions: {
              DirectionalFocusIntent: TvEdgeFocusAction(onEdge: edges.add),
            },
            child: FocusScope(
              node: scope,
              child: Column(
                children: [
                  Row(children: [_tile('g0', autofocus: true), _tile('g1')]),
                  Row(children: [_tile('g2'), _tile('g3')]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    Future<void> press(LogicalKeyboardKey k) async {
      await t.sendKeyEvent(k);
      await t.pump();
    }

    expect(isFocused(t, const ValueKey('g0')), isTrue);
    await press(LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('g1')), isTrue);
    await press(LogicalKeyboardKey.arrowDown);
    expect(isFocused(t, const ValueKey('g3')), isTrue);
    await press(LogicalKeyboardKey.arrowLeft);
    expect(isFocused(t, const ValueKey('g2')), isTrue);
    expect(edges, isEmpty);
    await press(LogicalKeyboardKey.arrowLeft);
    expect(isFocused(t, const ValueKey('g2')), isTrue);
    expect(edges, [TraversalDirection.left]);

    // El scope recuerda el último enfocado.
    t
        .state<TvFocusableState>(find.byKey(const ValueKey('side')))
        .focusNode
        .requestFocus();
    await t.pump();
    expect(isFocused(t, const ValueKey('side')), isTrue);
    expect(focusFirstIn(scope), isTrue);
    await t.pump();
    expect(isFocused(t, const ValueKey('g2')), isTrue);
  });

  testWidgets('scope nunca enfocado enfoca el primero', (t) async {
    final scope = FocusScopeNode();
    await pumpTv(
      t,
      FocusScope(
        node: scope,
        child: Row(children: [_tile('a'), _tile('b')]),
      ),
    );
    expect(focusFirstIn(scope), isTrue);
    await t.pump();
    expect(isFocused(t, const ValueKey('a')), isTrue);
  });

  testWidgets('scope sin enfocables devuelve false y no mueve el foco',
      (t) async {
    final scope = FocusScopeNode();
    await pumpTv(
      t,
      Row(
        children: [
          _tile('side', autofocus: true),
          FocusScope(node: scope, child: const SizedBox(width: 50, height: 50)),
        ],
      ),
    );
    expect(focusFirstIn(scope), isFalse);
    await t.pump();
    expect(isFocused(t, const ValueKey('side')), isTrue);
  });
}
