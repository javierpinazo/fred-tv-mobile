import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend/sql.dart';
import '../models/channel.dart';
import '../models/filters.dart';
import '../models/view_type.dart';
import '../player.dart';

class SimpleTVTest extends StatefulWidget {
  @override
  State<SimpleTVTest> createState() => _SimpleTVTestState();
}

class _SimpleTVTestState extends State<SimpleTVTest> {
  int _selectedIndex = 0;
  List<Channel> _channels = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _gridFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _gridFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      // Cargar canales reales desde la base de datos
      final sources = await Sql.getEnabledSourcesMinimal();

      final filters = Filters(
        viewType: ViewType.all,
        page: 1,
      );
      filters.sourceIds = sources.map((x) => x.id).toList();

      final channels = await Sql.search(filters);

      setState(() {
        _channels = channels.take(100).toList(); // Limitar a 100 canales
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando canales: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Cargando canales...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    if (_channels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tv_off, color: Colors.grey, size: 64),
              SizedBox(height: 20),
              Text(
                'No hay canales disponibles',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              SizedBox(height: 10),
              Text(
                'Por favor configura una fuente primero',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: Column(
            children: [
              // Header con logo/título
              Row(
                children: [
                  Icon(
                    Icons.tv,
                    color: Colors.blue,
                    size: 48,
                  ),
                  SizedBox(width: 20),
                  Text(
                    'Fred TV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${_channels.length} canales',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 20,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32),

              // Grid de canales con soporte para D-pad
              Expanded(
                child: GridView.builder(
                  controller: _scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _channels.length,
                  itemBuilder: (context, index) {
                    final channel = _channels[index];
                    return _buildChannelCard(channel, index);
                  },
                ),
              ),

              SizedBox(height: 16),

              // Footer con instrucciones
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInstructionItem('D-PAD', 'Navegar'),
                    SizedBox(width: 40),
                    _buildInstructionItem('ENTER/OK', 'Reproducir'),
                    SizedBox(width: 40),
                    _buildInstructionItem('BACK', 'Volver'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelCard(Channel channel, int index) {
    return Focus(
      autofocus: index == 0,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          setState(() {
            _selectedIndex = index;
          });
          // Auto-scroll cuando el elemento está fuera de vista
          _scrollController.position.ensureVisible(
            context.findRenderObject()!,
            alignment: 0.5,
            duration: Duration(milliseconds: 300),
          );
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.mediaPlay) {
            _selectChannel(channel);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _selectedIndex == index
              ? Colors.blue.withOpacity(0.8)
              : Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: _selectedIndex == index
              ? Border.all(color: Colors.white, width: 3)
              : Border.all(color: Colors.grey[700]!, width: 1),
          boxShadow: _selectedIndex == index
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 3,
                  )
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo o icono del canal
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _selectedIndex == index
                      ? Colors.white.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: channel.image != null && channel.image!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          channel.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.tv,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.tv,
                        color: Colors.white,
                        size: 28,
                      ),
              ),

              SizedBox(width: 16),

              // Información del canal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      channel.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _selectedIndex == index ? 18 : 16,
                        fontWeight: _selectedIndex == index
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (channel.group != null && channel.group!.isNotEmpty)
                      Text(
                        channel.group!,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Indicador de reproducción
              if (_selectedIndex == index)
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String key, String action) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            key,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          action,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  void _selectChannel(Channel channel) {
    // Navegar al reproductor con el canal seleccionado
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Player(channel: channel),
      ),
    );
  }
}