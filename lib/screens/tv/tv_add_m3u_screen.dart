import 'package:flutter/material.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/tv_source_errors.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_text_field.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Formulario para agregar una lista M3U por URL.
class TvAddM3uScreen extends StatefulWidget {
  const TvAddM3uScreen({super.key, required this.data});

  final TvData data;

  @override
  State<TvAddM3uScreen> createState() => _TvAddM3uScreenState();
}

class _TvAddM3uScreenState extends State<TvAddM3uScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();
  String? _message;
  bool _isError = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _setMessage(String text, {required bool error}) {
    setState(() {
      _message = text;
      _isError = error;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    final url = _url.text.trim();
    if (name.isEmpty || url.isEmpty) {
      _setMessage(context.l10n.addM3uFillAll, error: true);
      return;
    }
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      _setMessage(context.l10n.urlMustBeHttp, error: true);
      return;
    }
    _busy = true;
    _setMessage(context.l10n.addM3uAdding, error: false);
    try {
      await widget.data.addSource(Source(
        name: name,
        url: url,
        sourceType: SourceType.m3uUrl,
        enabled: true,
      ));
      if (!mounted) return;
      _name.clear();
      _url.clear();
      _setMessage(context.l10n.addM3uAdded, error: false);
    } catch (e) {
      debugPrint('TvAddM3uScreen: error agregando "$name": $e');
      if (!mounted) return;
      _setMessage(tvAddSourceErrorMessage(e, context.l10n), error: true);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvTheme.background,
      body: Padding(
        padding: TvTheme.safeArea,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.addM3uTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: TvTheme.fontTitle,
                      fontWeight: FontWeight.bold,
                      color: TvTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TvTextField(
                    key: const ValueKey('tv-m3u-name'),
                    controller: _name,
                    label: context.l10n.playlistNameLabel,
                    icon: Icons.label_outline,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TvTextField(
                    key: const ValueKey('tv-m3u-url'),
                    controller: _url,
                    label: context.l10n.addM3uUrlLabel,
                    icon: Icons.link,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),
                  TvFocusable(
                    key: const ValueKey('tv-m3u-add'),
                    onSelect: _submit,
                    builder: (context, focused) => Container(
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TvTheme.accent,
                        borderRadius: BorderRadius.circular(TvTheme.radius - 2),
                      ),
                      child: Text(
                        context.l10n.addM3uButton,
                        style: const TextStyle(
                          fontSize: TvTheme.fontBody,
                          fontWeight: FontWeight.bold,
                          color: TvTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: TvTheme.fontBody,
                        color: _isError ? TvTheme.error : TvTheme.success,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
