import 'package:flutter/material.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_text_field.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

Widget _button(
  String label, {
  Key? key,
  required VoidCallback onSelect,
  bool autofocus = false,
  bool filled = false,
}) {
  return TvFocusable(
    key: key,
    autofocus: autofocus,
    onSelect: onSelect,
    builder: (context, focused) => Container(
      constraints: const BoxConstraints(minWidth: 140, minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled
            ? TvTheme.accent
            : (focused ? TvTheme.surfaceRaised : TvTheme.surface),
        borderRadius: BorderRadius.circular(TvTheme.radius - 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: TvTheme.fontBody,
          color: TvTheme.textPrimary,
        ),
      ),
    ),
  );
}

Widget _dialog({required Widget child}) {
  return Dialog(
    backgroundColor: TvTheme.surface,
    insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 48),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(padding: const EdgeInsets.all(28), child: child),
    ),
  );
}

/// Confirmación. El foco inicial está en "Cancelar".
Future<bool> showTvConfirm(
  BuildContext context, {
  required String message,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: TvTheme.fontBody,
              color: TvTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _button(
                confirmLabel ?? ctx.l10n.commonDelete,
                key: const ValueKey('tv-confirm-ok'),
                onSelect: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(width: 20),
              _button(
                cancelLabel ?? ctx.l10n.commonCancel,
                key: const ValueKey('tv-confirm-cancel'),
                autofocus: true,
                onSelect: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Pide un texto. Devuelve el texto con `trim()` o `null` si se cancela o queda vacío.
Future<String?> showTvTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? confirmLabel,
}) async {
  final controller = TextEditingController(text: initial);
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => _dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: TvTheme.fontTitle,
                fontWeight: FontWeight.bold,
                color: TvTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            TvTextField(
              key: const ValueKey('tv-prompt-field'),
              controller: controller,
              label: label,
              autofocus: true,
            ),
            const SizedBox(height: 20),
            _button(
              confirmLabel ?? ctx.l10n.commonSave,
              key: const ValueKey('tv-prompt-confirm'),
              filled: true,
              onSelect: () {
                final text = controller.text.trim();
                Navigator.of(ctx).pop(text.isEmpty ? null : text);
              },
            ),
            const SizedBox(height: 12),
            _button(
              ctx.l10n.commonCancel,
              key: const ValueKey('tv-prompt-cancel'),
              onSelect: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// Lista de opciones; devuelve el valor elegido o `null` si se cierra con Atrás.
Future<T?> showTvOptions<T>(
  BuildContext context, {
  required String title,
  required List<(String label, T value)> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => _dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: TvTheme.fontTitle,
              fontWeight: FontWeight.bold,
              color: TvTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: TvFocusable(
                          key: ValueKey('tv-option-$i'),
                          autofocus: i == 0,
                          scaleOnFocus: false,
                          onSelect: () =>
                              Navigator.of(ctx).pop(options[i].$2),
                          builder: (context, focused) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: focused
                                  ? TvTheme.surfaceRaised
                                  : TvTheme.surface,
                              borderRadius:
                                  BorderRadius.circular(TvTheme.radius - 2),
                            ),
                            child: Text(
                              options[i].$1,
                              style: const TextStyle(
                                fontSize: TvTheme.fontBody,
                                color: TvTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
