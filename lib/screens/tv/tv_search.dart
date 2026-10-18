import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/tv_search_filters.dart';
import 'package:open_tv/player.dart';

class TVSearch extends StatefulWidget {
  const TVSearch({super.key});

  @override
  State<TVSearch> createState() => _TVSearchState();
}

class _TVSearchState extends State<TVSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  List<Channel> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final sources = await Sql.getEnabledSourcesMinimal();
      final sourceIds = sources.map((x) => x.id).toList();

      final filters = buildTvSearchFilters(query, sourceIds);
      final results =
          filters == null ? <Channel>[] : await Sql.search(filters);

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      print("Error searching: $e");
      setState(() => _loading = false);
    }
  }

  void _playChannel(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Player(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _controller,
            focusNode: _inputFocusNode,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search channels...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
            onSubmitted: _performSearch,
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        _controller.text.isEmpty 
                            ? 'Type to search' 
                            : 'No results found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 18),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final channel = _results[index];
                        return Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.enter || 
                                  event.logicalKey == LogicalKeyboardKey.select ||
                                  event.logicalKey == LogicalKeyboardKey.space) {
                                _playChannel(channel);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Builder(
                            builder: (context) {
                              final hasFocus = Focus.of(context).hasFocus;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                  border: hasFocus 
                                      ? Border.all(color: Colors.blue, width: 3) 
                                      : Border.all(color: Colors.transparent),
                                  boxShadow: hasFocus 
                                      ? [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10)] 
                                      : [],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                        child: channel.image != null && channel.image!.isNotEmpty
                                            ? Image.network(
                                                channel.image!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: Colors.white54),
                                              )
                                            : const Icon(Icons.tv, color: Colors.white54),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        channel.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
