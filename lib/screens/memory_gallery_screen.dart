import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';
import '../widget/MemoryDetailScreen.dart';
import 'coordinate_input_screen.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import '../providers/favorite_provider.dart';
import 'favorite_screen.dart';
import '../widget/MemoryThumbnail.dart';

class MemoryGalleryScreen extends StatefulWidget {
  const MemoryGalleryScreen({super.key});

  @override
  State<MemoryGalleryScreen> createState() => _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  final MemoryService _memoryService = MemoryService();
  List<Memory> _memories = [];
  bool _isLoading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    try {
      final memories = await _memoryService.getMemories();
      if (mounted) {
        Provider.of<FavoriteProvider>(context, listen: false).loadFavorites(memories);
        setState(() {
          _memories = memories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando recuerdos: $e');
      if (mounted) {
        setState(() {
          _memories = [];
          _isLoading = false;
        });
      }
    }
  }

  // Agrupa los recuerdos por el String de su categoría
  Map<String, List<Memory>> _groupMemoriesByCategory() {
    Map<String, List<Memory>> grouped = {};
    for (var memory in _memories) {
      grouped.putIfAbsent(memory.category, () => []).add(memory);
    }
    return grouped;
  }

  // Obtiene el último recuerdo de una categoría para usarlo de miniatura
  Memory? _getLastMemoryForCategory(String category, Map<String, List<Memory>> grouped) {
    final memories = grouped[category];
    if (memories == null || memories.isEmpty) return null;
    return memories.last;
  }

  void _navigateToCreateMemory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CoordinateInputScreen()),
    ).then((_) => _loadMemories());
  }

  void _showMemoryDetails(BuildContext context, Memory memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemoryDetailScreen(
        memory: memory,
        onEdit: () async {
          Navigator.pop(context);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => CoordinateInputScreen(existingMemory: memory),
            ),
          );
          if (result != null && result is Memory) {
            await _memoryService.saveMemory(result);
            _loadMemories();
          }
        },
        onDelete: () async {
          try {
            await _memoryService.deleteMemory(memory.id);
            Navigator.pop(context);
            _loadMemories();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        },
        onUpdate: (updatedMemory) async {
          await _memoryService.saveMemory(updatedMemory);
          _loadMemories();
        },
      ),
    );
  }

  // Cuadrícula de Carpetas
  Widget _buildFolderGrid(
    BuildContext context,
    List<String> categories,
    Map<String, List<Memory>> grouped,
    ThemeProvider themeProvider,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final lastMemory = _getLastMemoryForCategory(cat, grouped);

        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: Container(
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode ? cardDark : pinkLighter,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Icono de carpeta de fondo
                    Icon(
                      Icons.folder,
                      size: 90,
                      color: pinkPrimary.withOpacity(0.8),
                    ),
                    // Imagen miniatura superpuesta "dentro" de la carpeta
                    if (lastMemory != null && lastMemory.imageAsset != null)
                      Positioned(
                        top: 30,
                        child: Container(
                          width: 45,
                          height: 35,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 2)
                            ],
                          ),
                          child: MemoryThumbnail(
                            imagePath: lastMemory.imageAsset,
                            width: 45,
                            height: 35,
                            borderRadius: 4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cat,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: themeProvider.isDarkMode ? textDarkMode : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${grouped[cat]!.length} recuerdos',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //Listado de recuerdos de una carpeta específica
  Widget _buildMemoryList(
    BuildContext context,
    List<Memory> memories,
    ThemeProvider themeProvider,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final memory = memories[index];
        return GestureDetector(
          onTap: () => _showMemoryDetails(context, memory),
          child: Card(
            elevation: 3,
            color: themeProvider.isDarkMode ? cardDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: MemoryThumbnail(
                      imagePath: memory.imageAsset,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              memory.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: themeProvider.isDarkMode ? textDarkMode : Colors.black87,
                              ),
                            ),
                            Text(
                              memory.date.split('T')[0],
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Consumer<FavoriteProvider>(
                        builder: (context, fav, _) {
                          final isFav = fav.isFavorite(memory.id);
                          return IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? pinkPrimary : Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => fav.toggleFavorite(memory.id),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final groupedMemories = _groupMemoriesByCategory();
    final categories = groupedMemories.keys.toList();

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : Colors.white,
      appBar: AppBar(
        title: Text(
          _selectedCategory ?? 'Mis Carpetas',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: pinkPrimary,
        // Si hay categoría seleccionada, mostramos botón de volver
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoriteScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToCreateMemory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: pinkPrimary))
          : _memories.isEmpty
              ? _buildEmptyState(themeProvider)
              : _selectedCategory == null
                  ? _buildFolderGrid(context, categories, groupedMemories, themeProvider)
                  : _buildMemoryList(context, groupedMemories[_selectedCategory]!, themeProvider),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No hay recuerdos aún', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _navigateToCreateMemory,
            style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
            child: const Text('Crear mi primer recuerdo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}