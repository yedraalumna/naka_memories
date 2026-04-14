import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/Memory.dart';
import '../services/MemoryService.dart';
import '../providers/favorite_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import '../widget/MemoryListTile.dart';
import 'coordinate_input_screen.dart';

/// Pantalla que muestra la lista de recuerdos marcados como favoritos
class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final MemoryService _memoryService = MemoryService();
  late Future<List<Memory>> _memoriesFuture;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  /// Carga o recarga la lista de recuerdos desde la base de datos
  void _loadMemories() {
    setState(() {
      _memoriesFuture = _memoryService.getMemories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = context.watch<FavoriteProvider>().favoriteIds;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? backgroundDark : Colors.white,
      appBar: AppBar(
        title: Text(
          'Mis Favoritos',
          style: TextStyle(
            color: isDarkMode ? textDarkMode : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? backgroundDark : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? textDarkMode : Colors.black87,
        ),
      ),
      body: favoriteIds.isEmpty
          ? _buildEmptyState(isDarkMode)
          : FutureBuilder<List<Memory>>(
              future: _memoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: pinkPrimary),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isDarkMode);
                }

                // Filtramos los recuerdos que estén en la lista de favoritos
                final favoriteMemories = snapshot.data!
                    .where((memory) => favoriteIds.contains(memory.id))
                    .toList();

                // Si hay IDs en favoritos pero no se encuentran en la BD (pq se borró desde otro dispositivo)
                if (favoriteMemories.isEmpty) {
                  return _buildEmptyState(isDarkMode);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: favoriteMemories.length,
                  itemBuilder: (context, index) {
                    final memory = favoriteMemories[index];
                    return MemoryListTile(
                      memory: memory,
                      onEdit: () async {
                        Navigator.pop(context); // Cierra el modal de detalles
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) =>
                                CoordinateInputScreen(existingMemory: memory),
                          ),
                        );
                        if (result != null && result is Memory) {
                          await _memoryService.saveMemory(result);
                          if (mounted) _loadMemories(); // Recarga la lista
                        }
                      },
                      onDelete: () async {
                        await _memoryService.deleteMemory(memory.id);

                        if (!context.mounted) {
                          return;
                        }

                        Navigator.pop(context);
                        _loadMemories(); // Recarga la lista
                      },
                      onUpdate: (updatedMemory) async {
                        await _memoryService.saveMemory(updatedMemory);
                        if (mounted) _loadMemories(); // Recarga la lista
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  /// Método que construye la vista cuando no hay favoritos
  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Aún no tienes favoritos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[400] : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
