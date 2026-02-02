import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';
import '../widget/MemoryDetailScreen.dart';
import 'coordinate_input_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import 'dart:io'; //Importante para poder leer archivos del dispositivo
import 'package:flutter/foundation.dart';

// 1. Pantalla de Galería
class MemoryGalleryScreen extends StatefulWidget {
  const MemoryGalleryScreen({super.key});

  @override
  State<MemoryGalleryScreen> createState() {
    return _MemoryGalleryScreenState();
  }
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  final MemoryService _memoryService = MemoryService();
  List<Memory> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final memories = await _memoryService.getMemories();
      setState(() {
        _memories = memories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando recuerdos: $e');
      setState(() {
        _memories = [];
        _isLoading = false;
      });
    }
  }

  void _showMemoryDetails(BuildContext context, Memory memory) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemoryDetailScreen(
        memory: memory,
        onEdit: () async {
          Navigator.pop(context); // Cerrar modal de detalles

          // Navegar a edición PASANDO la memoria existente
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => CoordinateInputScreen(
                existingMemory:
                    memory, // ← PASAMOS la memoria para editar ubicación
              ),
            ),
          );

          // Procesar el resultado: Si se devolvió una memoria actualizada, guardarla
          if (result != null && result is Memory) {
            await _memoryService.saveMemory(result);
            _loadMemories(); // Recargar la lista
          }
        },
        onDelete: () async {
          try {
            await _memoryService.deleteMemory(memory.id);
            Navigator.pop(context);
            _loadMemories();
          } catch (e) {
            print('Error eliminando: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        // NUEVO: callback para actualizar la memoria cuando se edita todo
        onUpdate: (updatedMemory) async {
          await _memoryService.saveMemory(updatedMemory);
          _loadMemories(); // Recargar la lista

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recuerdo actualizado correctamente'),
              backgroundColor: pinkPrimary,
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  // Método que soporta Assets y Fotos de la camara o la galeria
  Widget _buildMemoryImage(Memory memory) {
    if (memory.imageAsset != null && memory.imageAsset!.isNotEmpty) {
      // Asset
      if (memory.imageAsset!.startsWith('assets/')) {
        return Image.asset(
          memory.imageAsset!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
      // WEB
      else if (kIsWeb) {
        return Image.network(
          memory.imageAsset!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
      // Móvil
      else {
        return Image.file(
          File(memory.imageAsset!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 8),
            const Text(
              'Sin imagen',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Memory Places',
          style: TextStyle(
            color: themeProvider.isDarkMode ? textDarkMode : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            themeProvider.isDarkMode ? backgroundDark : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: themeProvider.isDarkMode ? textDarkMode : Colors.black87,
        ),
      ),
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: pinkPrimary))
          : _memories.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_library,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No hay recuerdos aún',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Agrega tu primer recuerdo desde el mapa',
                          style: TextStyle(
                            fontSize: 14,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _memories.length,
                  itemBuilder: (context, index) {
                    final memory = _memories[index];
                    return GestureDetector(
                      onTap: () {
                        _showMemoryDetails(context, memory);
                      },
                      child: Card(
                        elevation: 3,
                        color:
                            themeProvider.isDarkMode ? cardDark : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Imagen
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: _buildMemoryImage(memory),
                              ),
                            ),
                            // Título
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    memory.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: themeProvider.isDarkMode
                                          ? textDarkMode
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    memory.date,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// 2. Pantalla Principal
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const MemoryGalleryScreen(),
    MapScreen(isLibrary: true),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Biblioteca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: pinkPrimary,
        unselectedItemColor:
            themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
        backgroundColor:
            themeProvider.isDarkMode ? backgroundDark : Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 5,
        onTap: _onItemTapped,
      ),
    );
  }
}
