import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/player.dart';

class TVChannelBrowser extends StatefulWidget {
  final VoidCallback? onBackToMenu;
  final FocusNode? contentFocusNode;
  final bool favoritesOnly;

  const TVChannelBrowser({
    super.key,
    this.onBackToMenu,
    this.contentFocusNode,
    this.favoritesOnly = false,
  });

  @override
  State<TVChannelBrowser> createState() => _TVChannelBrowserState();
}

class _TVChannelBrowserState extends State<TVChannelBrowser> {
  // Data
  List<Channel> _groups = [];
  List<Channel> _channels = [];
  
  // State
  bool _loadingGroups = true;
  bool _loadingChannels = false;
  int _selectedGroupIndex = 0;
  int _selectedChannelIndex = -1; // -1 means focus is on groups
  
  // Pagination
  int _channelPage = 1;
  bool _hasMoreChannels = true;
  bool _isLoadingMoreChannels = false;

  // Controllers
  final ScrollController _groupScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  // Focus nodes for channels and groups
  final Map<int, FocusNode> _channelFocusNodes = {};
  final Map<int, FocusNode> _groupFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadGroups();

    // Listen to content focus node to pass focus to first group
    if (widget.contentFocusNode != null) {
      widget.contentFocusNode!.addListener(_handleContentFocusChange);
    }
  }

  void _handleContentFocusChange() {
    if (widget.contentFocusNode!.hasFocus) {
      // Move focus to first group
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_groups.isNotEmpty) {
          final firstGroupNode = _getGroupFocusNode(0);
          firstGroupNode.requestFocus();
        }
      });
    }
  }

  Future<void> _toggleFavorite(Channel channel) async {
    try {
      await Sql.favoriteChannel(channel.id!, !channel.favorite);
      setState(() {
        channel.favorite = !channel.favorite;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(channel.favorite ? "Added to favorites" : "Removed from favorites"),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      print("Error toggling favorite: $e");
    }
  }

  @override
  void dispose() {
    if (widget.contentFocusNode != null) {
      widget.contentFocusNode!.removeListener(_handleContentFocusChange);
    }
    _groupScrollController.dispose();
    _channelScrollController.dispose();
    // Dispose all focus nodes
    for (var node in _channelFocusNodes.values) {
      node.dispose();
    }
    for (var node in _groupFocusNodes.values) {
      node.dispose();
    }
    _channelFocusNodes.clear();
    _groupFocusNodes.clear();
    super.dispose();
  }

  FocusNode _getChannelFocusNode(int index) {
    return _channelFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  FocusNode _getGroupFocusNode(int index) {
    return _groupFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  void _scrollToGroup(int index) {
    const itemHeight = 48.0; // Approximate height of each group item
    final targetOffset = index * itemHeight;
    _groupScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToChannel(int index) {
    const itemHeight = 150.0; // Approximate height of each row (based on aspect ratio 1.5)
    const crossAxisCount = 4;
    final row = index ~/ crossAxisCount;
    final targetOffset = row * itemHeight;
    _channelScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      // Add test channels on first load (only for main channel browser)
      if (!widget.favoritesOnly) {
        await Sql.addTestChannels();
      }

      final sources = await Sql.getEnabledSourcesMinimal();
      final sourceIds = sources.map((x) => x.id).toList();

      if (widget.favoritesOnly) {
        // For favorites view, skip groups and load favorites directly
        setState(() {
          _groups = [
            Channel(
              id: -1,
              name: "My Favorites",
              mediaType: MediaType.group,
              sourceId: -1,
              favorite: false
            )
          ];
          _loadingGroups = false;
        });
        _loadChannels(0);
        return;
      }

      final filters = Filters(
        viewType: ViewType.categories,
        sourceIds: sourceIds,
        mediaTypes: [MediaType.livestream], // Focus on Live TV for now
      );

      final groups = await Sql.searchGroup(filters);

      // Add "All Channels" pseudo-group at the beginning
      final allChannelsGroup = Channel(
        id: -1,
        name: "All Channels",
        mediaType: MediaType.group,
        sourceId: -1,
        favorite: false
      );

      setState(() {
        _groups = [allChannelsGroup, ...groups];
        _loadingGroups = false;
      });

      // Load channels for the first group (All Channels)
      _loadChannels(0);

    } catch (e) {
      print("Error loading groups: $e");
      setState(() => _loadingGroups = false);
    }
  }

  Future<void> _loadChannels(int groupIndex, {bool loadMore = false}) async {
    if (groupIndex < 0 || groupIndex >= _groups.length) return;

    if (!loadMore) {
      setState(() {
        _loadingChannels = true;
        _channels = [];
        _channelPage = 1;
        _hasMoreChannels = true;
      });
    } else {
      if (_isLoadingMoreChannels || !_hasMoreChannels) return;
      setState(() => _isLoadingMoreChannels = true);
    }

    try {
      final group = _groups[groupIndex];
      final sources = await Sql.getEnabledSourcesMinimal();
      final sourceIds = sources.map((x) => x.id).toList();

      final filters = Filters(
        viewType: widget.favoritesOnly ? ViewType.favorites : ViewType.all,
        sourceIds: sourceIds,
        mediaTypes: [MediaType.livestream],
        page: loadMore ? _channelPage + 1 : 1,
        groupId: widget.favoritesOnly ? null : (group.id == -1 ? null : group.id),
      );

      final newChannels = await Sql.search(filters);

      setState(() {
        if (loadMore) {
          _channels.addAll(newChannels);
          _channelPage++;
          _isLoadingMoreChannels = false;
        } else {
          _channels = newChannels;
          _loadingChannels = false;
        }
        _hasMoreChannels = newChannels.length >= 36; // Assuming pageSize is 36
      });
    } catch (e) {
      print("Error loading channels: $e");
      setState(() {
        _loadingChannels = false;
        _isLoadingMoreChannels = false;
      });
    }
  }

  void _onGroupSelected(int index) {
    if (_selectedGroupIndex == index) return;
    setState(() {
      _selectedGroupIndex = index;
      _selectedChannelIndex = -1; // Reset channel selection
    });
    _loadChannels(index);
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
    if (_loadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    return Focus(
      focusNode: widget.contentFocusNode,
      canRequestFocus: true,
      skipTraversal: true,
      child: Row(
      children: [
        // Groups List (Left Side)
        SizedBox(
          width: 250,
          child: Container(
            color: Colors.grey[900],
            child: ListView.builder(
            controller: _groupScrollController,
            itemCount: _groups.length,
            itemBuilder: (context, index) {
                final group = _groups[index];
                final isSelected = _selectedGroupIndex == index;
                final hasFocus = _selectedChannelIndex == -1 && isSelected;

                return Focus(
                  focusNode: _getGroupFocusNode(index),
                  canRequestFocus: true,
                  skipTraversal: false,
                  onFocusChange: (focused) {
                    if (focused) {
                      setState(() {
                        _selectedGroupIndex = index;
                        _selectedChannelIndex = -1;
                      });
                      _loadChannels(index);
                    }
                  },
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      // Handle UP - go to previous group
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        if (index > 0) {
                          _getGroupFocusNode(index - 1).requestFocus();
                          _scrollToGroup(index - 1);
                        }
                        return KeyEventResult.handled;
                      }
                      // Handle DOWN - go to next group
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        if (index < _groups.length - 1) {
                          _getGroupFocusNode(index + 1).requestFocus();
                          _scrollToGroup(index + 1);
                        }
                        return KeyEventResult.handled;
                      }
                      // Handle RIGHT - go to channels
                      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        if (_channels.isNotEmpty) {
                          setState(() => _selectedChannelIndex = 0);
                          _getChannelFocusNode(0).requestFocus();
                        }
                        return KeyEventResult.handled;
                      }
                      // Handle LEFT - go back to menu
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        widget.onBackToMenu?.call();
                        return KeyEventResult.handled;
                      }
                      // Handle SELECT/ENTER - also go to channels
                      if (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        if (_channels.isNotEmpty) {
                          setState(() => _selectedChannelIndex = 0);
                          _getChannelFocusNode(0).requestFocus();
                        }
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.handled;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: isSelected 
                        ? (hasFocus ? Colors.blue : Colors.blue.withOpacity(0.5)) 
                        : Colors.transparent,
                    child: Text(
                      group.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        // Channels Grid (Right Side)
        Expanded(
          child: _loadingChannels
              ? const Center(child: CircularProgressIndicator())
              : _channels.isEmpty
                  ? const Center(child: Text("No channels found", style: TextStyle(color: Colors.white)))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (!_isLoadingMoreChannels && 
                            _hasMoreChannels && 
                            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                          _loadChannels(_selectedGroupIndex, loadMore: true);
                        }
                        return false;
                      },
                      child: GridView.builder(
                        controller: _channelScrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _channels.length + (_isLoadingMoreChannels ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _channels.length) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final channel = _channels[index];
                          final isSelected = _selectedChannelIndex == index;

                          return Focus(
                            focusNode: _getChannelFocusNode(index),
                            canRequestFocus: true,
                            skipTraversal: false,
                            onFocusChange: (focused) {
                              if (focused) {
                                setState(() => _selectedChannelIndex = index);
                              }
                            },
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent) {
                                const crossAxisCount = 4; // Number of columns in grid

                                // Handle UP - go to channel in previous row
                                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                  final targetIndex = index - crossAxisCount;
                                  if (targetIndex >= 0) {
                                    setState(() => _selectedChannelIndex = targetIndex);
                                    _getChannelFocusNode(targetIndex).requestFocus();
                                    _scrollToChannel(targetIndex);
                                  }
                                  return KeyEventResult.handled;
                                }

                                // Handle DOWN - go to channel in next row
                                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                  final targetIndex = index + crossAxisCount;
                                  if (targetIndex < _channels.length) {
                                    setState(() => _selectedChannelIndex = targetIndex);
                                    _getChannelFocusNode(targetIndex).requestFocus();
                                    _scrollToChannel(targetIndex);
                                  }
                                  return KeyEventResult.handled;
                                }

                                // Handle LEFT - go to previous channel or back to groups
                                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                  if (index % crossAxisCount == 0) {
                                    // On left edge, go back to groups
                                    setState(() => _selectedChannelIndex = -1);
                                    _getGroupFocusNode(_selectedGroupIndex).requestFocus();
                                  } else {
                                    // Go to previous channel
                                    final targetIndex = index - 1;
                                    setState(() => _selectedChannelIndex = targetIndex);
                                    _getChannelFocusNode(targetIndex).requestFocus();
                                  }
                                  return KeyEventResult.handled;
                                }

                                // Handle RIGHT - go to next channel
                                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                  final targetIndex = index + 1;
                                  if (targetIndex < _channels.length) {
                                    setState(() => _selectedChannelIndex = targetIndex);
                                    _getChannelFocusNode(targetIndex).requestFocus();
                                  }
                                  return KeyEventResult.handled;
                                }

                                // Handle SELECT/ENTER - play channel
                                if (event.logicalKey == LogicalKeyboardKey.enter ||
                                    event.logicalKey == LogicalKeyboardKey.select) {
                                  _playChannel(channel);
                                  return KeyEventResult.handled;
                                }

                                // Handle MENU/INFO/F2 - toggle favorite (most TV remotes use these)
                                if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                                    event.logicalKey == LogicalKeyboardKey.f2 ||
                                    event.logicalKey == LogicalKeyboardKey.info ||
                                    event.logicalKey == LogicalKeyboardKey.mediaRecord) {
                                  _toggleFavorite(channel);
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.handled;
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: channel.favorite ? Colors.amber.withOpacity(0.2) : Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(color: Colors.blue, width: 3)
                                    : channel.favorite
                                        ? Border.all(color: Colors.amber, width: 1)
                                        : Border.all(color: Colors.transparent),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10)]
                                    : [],
                              ),
                              child: Stack(
                                children: [
                                  Column(
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
                                  // Favorite indicator
                                  if (channel.favorite)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.star, color: Colors.white, size: 16),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
      ),
    );
  }
}
