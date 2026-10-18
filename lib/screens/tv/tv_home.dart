import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/screens/tv/tv_channel_browser.dart';
import 'package:open_tv/screens/tv/tv_search.dart';
import 'package:open_tv/screens/tv/tv_settings.dart';

class TVHome extends StatefulWidget {
  const TVHome({super.key});

  @override
  State<TVHome> createState() => _TVHomeState();
}

class _TVHomeState extends State<TVHome> {
  int _selectedIndex = 0;
  bool _isNavigationFocused = true;
  // Key to force refresh of channel browser
  Key _browserKey = UniqueKey();
  Key _favoritesKey = UniqueKey();

  // FocusNodes para controlar el focus
  final FocusNode _contentFocusNode = FocusNode();
  final FocusNode _channelBrowserFocusNode = FocusNode();
  final FocusNode _favoritesBrowserFocusNode = FocusNode();
  final List<FocusNode> _navFocusNodes = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _contentFocusNode.dispose();
    _channelBrowserFocusNode.dispose();
    _favoritesBrowserFocusNode.dispose();
    for (var node in _navFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _getCurrentContentFocusNode() {
    switch (_selectedIndex) {
      case 0:
        return _channelBrowserFocusNode;
      case 1:
        return _favoritesBrowserFocusNode;
      default:
        return _channelBrowserFocusNode;
    }
  }

  void _onSourceAdded() {
    setState(() {
      _browserKey = UniqueKey();
      _selectedIndex = 0; // Switch back to channels
    });
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _NavigateUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NavigateDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _NavigateLeftIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _NavigateRightIntent(),
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NavigateUpIntent: CallbackAction<_NavigateUpIntent>(
            onInvoke: (_) => _handleUpNavigation(),
          ),
          _NavigateDownIntent: CallbackAction<_NavigateDownIntent>(
            onInvoke: (_) => _handleDownNavigation(),
          ),
          _NavigateLeftIntent: CallbackAction<_NavigateLeftIntent>(
            onInvoke: (_) => _handleLeftNavigation(),
          ),
          _NavigateRightIntent: CallbackAction<_NavigateRightIntent>(
            onInvoke: (_) => _handleRightNavigation(),
          ),
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Row(
            children: [
              // Side Navigation Rail - Custom with Focus support
              Container(
                width: 200,
                color: Colors.grey[900],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildNavItem(0, Icons.tv, 'Channels'),
                    _buildNavItem(1, Icons.star, 'Favorites'),
                    _buildNavItem(2, Icons.search, 'Search'),
                    _buildNavItem(3, Icons.settings, 'Settings'),
                  ],
                ),
              ),
              // Vertical Divider
              const VerticalDivider(thickness: 1, width: 1, color: Colors.grey),
              // Main Content Area
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    TVChannelBrowser(
                      key: _browserKey,
                      contentFocusNode: _channelBrowserFocusNode,
                      onBackToMenu: () {
                        setState(() => _isNavigationFocused = true);
                        _navFocusNodes[_selectedIndex].requestFocus();
                      },
                    ),
                    TVChannelBrowser(
                      key: _favoritesKey,
                      contentFocusNode: _favoritesBrowserFocusNode,
                      favoritesOnly: true,
                      onBackToMenu: () {
                        setState(() => _isNavigationFocused = true);
                        _navFocusNodes[_selectedIndex].requestFocus();
                      },
                    ),
                    const TVSearch(),
                    TVSettings(onSourceAdded: _onSourceAdded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final hasFocus = _isNavigationFocused && isSelected;

    return Focus(
      focusNode: _navFocusNodes[index],
      autofocus: index == 0,
      canRequestFocus: true,
      onFocusChange: (focused) {
        if (focused) {
          setState(() {
            _selectedIndex = index;
            _isNavigationFocused = true;
          });
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            setState(() {
              _selectedIndex = index;
              _isNavigationFocused = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _getCurrentContentFocusNode().requestFocus();
            });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: hasFocus
              ? Colors.blue
              : (isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: hasFocus
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: hasFocus || isSelected ? Colors.white : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: hasFocus || isSelected ? Colors.white : Colors.grey,
                fontWeight: hasFocus || isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleUpNavigation() {
    if (_isNavigationFocused && _selectedIndex > 0) {
      setState(() => _selectedIndex--);
      _navFocusNodes[_selectedIndex].requestFocus();
    }
  }

  void _handleDownNavigation() {
    if (_isNavigationFocused && _selectedIndex < 3) {
      setState(() => _selectedIndex++);
      _navFocusNodes[_selectedIndex].requestFocus();
    }
  }

  void _handleLeftNavigation() {
    if (!_isNavigationFocused) {
      setState(() => _isNavigationFocused = true);
      _navFocusNodes[_selectedIndex].requestFocus();
    }
  }

  void _handleRightNavigation() {
    if (_isNavigationFocused) {
      setState(() => _isNavigationFocused = false);
      // El contenido manejará su propio focus
    }
  }
}

// Custom Intents for navigation
class _NavigateUpIntent extends Intent {
  const _NavigateUpIntent();
}

class _NavigateDownIntent extends Intent {
  const _NavigateDownIntent();
}

class _NavigateLeftIntent extends Intent {
  const _NavigateLeftIntent();
}

class _NavigateRightIntent extends Intent {
  const _NavigateRightIntent();
}
