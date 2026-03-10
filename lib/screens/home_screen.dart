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
  
  // Lista de categorías predefinidas
  final List<String> _allCategories = Memory.categoriesList;
  
  // Categorías personalizadas
  final Set<String> _customCategories = {};

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
        Provider.of<FavoriteProvider>(context, listen: false)
            .loadFavorites(memories);
        setState(() {
          _memories = memories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando recuerdos: $e');
      if (mounted) {
        setState(() {
          _memories = [];
          _isLoading = false;
        });
      }
    }
  }

  // Mostrar diálogo para crear nueva carpeta
  void _showNewCategoryDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nueva Carpeta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresa el nombre de la nueva carpeta:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Ej: Vacaciones 2024',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final newCategory = controller.text.trim();
                if (newCategory.isNotEmpty) {
                  setState(() {
                    _customCategories.add(newCategory);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Carpeta "$newCategory" creada'),
                      backgroundColor: pinkPrimary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  // Navegar a crear recuerdo en la carpeta seleccionada
  void _navigateToCreateMemoryInCategory() {
    if (_selectedCategory == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoordinateInputScreen(
          initialCategory: _selectedCategory, // AHORA SÍ FUNCIONA
        ),
      ),
    ).then((_) => _loadMemories());
  }

  // Obtener todas las categorías
  List<String> _getAllCategories() {
    Set<String> allCategories = {..._allCategories, ..._customCategories};
    return allCategories.toList()..sort();
  }

  // Obtener recuerdos de una categoría
  List<Memory> _getMemoriesForCategory(String category) {
    return _memories.where((m) => m.category == category).toList();
  }

  // Obtener el último recuerdo de una categoría
  Memory? _getLastMemoryForCategory(String category) {
    final categoryMemories = _getMemoriesForCategory(category);
    if (categoryMemories.isEmpty) return null;
    return categoryMemories.last;
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
              builder: (ctx) => CoordinateInputScreen(
                existingMemory: memory,
              ),
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
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onUpdate: (updatedMemory) async {
          await _memoryService.saveMemory(updatedMemory);
          _loadMemories();
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

  // Vista de carpetas
  Widget _buildFolderGrid(
    BuildContext context,
    List<String> categories,
    ThemeProvider themeProvider,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 80,
              color: themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'No hay carpetas disponibles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Crea tu primera carpeta con el botón +',
              style: TextStyle(
                fontSize: 14,
                color: themeProvider.isDarkMode ? Colors.grey[500] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showNewCategoryDialog,
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Crear carpeta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
        final categoryMemories = _getMemoriesForCategory(cat);
        final lastMemory = categoryMemories.isNotEmpty ? categoryMemories.last : null;
        final memoryCount = categoryMemories.length;

        return GestureDetector(
          onTap: () {
            if (memoryCount > 0) {
              setState(() => _selectedCategory = cat);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('La carpeta "$cat" está vacía. Añade recuerdos desde el botón +'),
                  backgroundColor: pinkPrimary,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode ? cardDark : pinkLighter,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
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
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: memoryCount > 0 
                            ? pinkPrimary.withOpacity(0.1) 
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    if (lastMemory != null && lastMemory.imageAsset != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 50,
                          height: 50,
                          child: MemoryThumbnail(
                            imagePath: lastMemory.imageAsset,
                            width: 50,
                            height: 50,
                            borderRadius: 8,
                          ),
                        ),
                      )
                    else
                      Icon(
                        memoryCount > 0 ? Icons.folder : Icons.folder_open,
                        size: 50,
                        color: memoryCount > 0 ? pinkPrimary : Colors.grey,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  cat,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: themeProvider.isDarkMode
                        ? textDarkMode
                        : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  memoryCount == 0 
                      ? 'Carpeta vacía' 
                      : '$memoryCount ${memoryCount == 1 ? 'recuerdo' : 'recuerdos'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: memoryCount > 0
                        ? (themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600])
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Vista de recuerdos dentro de una carpeta
  Widget _buildMemoryList(
    BuildContext context,
    List<Memory> memories,
    ThemeProvider themeProvider,
  ) {
    if (memories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library,
              size: 80,
              color: themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Esta carpeta está vacía',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Añade tu primer recuerdo con el botón +',
              style: TextStyle(
                fontSize: 14,
                color: themeProvider.isDarkMode ? Colors.grey[500] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _navigateToCreateMemoryInCategory,
              icon: const Icon(Icons.add),
              label: const Text('Añadir recuerdo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                fontSize: 14,
                                color: themeProvider.isDarkMode
                                    ? textDarkMode
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              memory.date.split('T')[0],
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
                      Consumer<FavoriteProvider>(
                        builder: (context, favProvider, child) {
                          final isFav = favProvider.isFavorite(memory.id);
                          return SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? pinkPrimary : Colors.grey,
                                size: 22,
                              ),
                              onPressed: () =>
                                  favProvider.toggleFavorite(memory.id),
                            ),
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
    final allCategories = _getAllCategories();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedCategory ?? 'Mis Carpetas',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: pinkPrimary,
        elevation: 4,
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : null,
        actions: [
          // Botón + para crear recuerdo (solo visible dentro de una carpeta)
          if (_selectedCategory != null)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: _navigateToCreateMemoryInCategory,
              tooltip: 'Agregar recuerdo a esta carpeta',
            ),
          // Botón para crear nueva carpeta
          IconButton(
            icon: const Icon(Icons.create_new_folder, color: Colors.white, size: 28),
            onPressed: _showNewCategoryDialog,
            tooltip: 'Crear nueva carpeta',
          ),
          // Botón de favoritos
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoriteScreen(),
                ),
              );
            },
            tooltip: 'Ver favoritos',
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: pinkPrimary))
          : _selectedCategory == null
              ? _buildFolderGrid(context, allCategories, themeProvider)
              : _buildMemoryList(context,
                  _getMemoriesForCategory(_selectedCategory!), themeProvider),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
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