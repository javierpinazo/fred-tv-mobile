import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/utils.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';

class TVSettings extends StatefulWidget {
  final VoidCallback? onSourceAdded;
  
  const TVSettings({super.key, this.onSourceAdded});

  @override
  State<TVSettings> createState() => _TVSettingsState();
}

class _TVSettingsState extends State<TVSettings> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      setState(() => _statusMessage = "Please fill in all fields");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Adding source...";
    });

    try {
      if (await Sql.sourceNameExists(name)) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Name already exists";
        });
        return;
      }

      final result = await Error.tryAsync(() async {
        await Utils.processSource(
          Source(
            name: name,
            sourceType: SourceType.m3uUrl,
            url: url,
            enabled: true,
          ),
        );
      }, context, "Successfully added source");

      if (result.success) {
        setState(() {
          _statusMessage = "Source added successfully!";
          _nameController.clear();
          _urlController.clear();
        });
        widget.onSourceAdded?.call();
      } else {
         setState(() {
          _statusMessage = "Failed to add source";
        });
      }
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Add M3U Playlist",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Playlist Name",
                border: OutlineInputBorder(),
                filled: true,
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: "M3U URL",
                border: OutlineInputBorder(),
                filled: true,
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                onPressed: _addSource,
                icon: const Icon(Icons.add),
                label: const Text("Add Source"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusMessage!.contains("Success") ? Colors.green : Colors.red,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
