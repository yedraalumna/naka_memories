import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';
import '../widget/MemoryDetailScreen.dart';
import 'coordinate_input_screen.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import '../providers/favorite_provider.dart';
import 'favorite_screen.dart';
import '../widget/MemoryThumbnail.dart';
import '../providers/category_provider.dart';
import '../widget/pin_dialog.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widget/MemoryForm.dart';

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
        Provider.of<FavoriteProvider>(context, listen: false)
            .loadFavorites(memories);
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

  Map<String, List<Memory>> _groupMemoriesByCategory() {
    Map<String, List<Memory>> grouped = {};
    for (var memory in _memories) {
      grouped.putIfAbsent(memory.category, () => []).add(memory);
    }
    return grouped;
  }

  Memory? _getLastMemoryForCategory(
      String category, Map<String, List<Memory>> grouped) {
    final memories = grouped[category];
    if (memories == null || memories.isEmpty) return null;
    return memories.last;
  }

  // ✅ CORREGIDO: usa el nuevo PinDialog que devuelve true/false
  Future<void> _onFolderTap(
      String category, Map<String, List<Memory>> grouped) async {
    final memoriesInCategory = grouped[category] ?? [];

    final folderHasPassword = memoriesInCategory.any((m) => m.hasPassword);
    final passwordHash = folderHasPassword
        ? memoriesInCategory.firstWhere((m) => m.hasPassword).passwordHash
        : null;

    if (folderHasPassword && passwordHash != null && passwordHash.isNotEmpty) {
      final bool? correcto = await showDialog<bool>(
        context: context,
        builder: (ctx) => PinDialog(
          correctHash: passwordHash,
          titulo: 'PIN de: $category',
        ),
      );

      if (correcto == true && mounted) {
        setState(() => _selectedCategory = category);
      }
    } else {
      setState(() => _selectedCategory = category);
    }
  }

  void _showProtectFolderDialog(String category) {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proteger Carpeta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Ingresa un PIN de 6 dígitos para proteger esta carpeta:'),
              const SizedBox(height: 20),
              PinCodeTextField(
                appContext: context,
                controller: pinController,
                length: 6,
                obscureText: true,
                animationType: AnimationType.fade,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(8),
                  fieldHeight: 45,
                  fieldWidth: 35,
                  activeFillColor: pinkLighter,
                  activeColor: pinkPrimary,
                ),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
            onPressed: () async {
              final pin = pinController.text;
              if (pin.length == 6) {
                final hash = sha256.convert(utf8.encode(pin)).toString();

                for (var memory
                    in _memories.where((m) => m.category == category)) {
                  final updatedMemory = memory.copyWith(
                    hasPassword: true,
                    passwordHash: hash,
                  );
                  await _memoryService.saveMemory(updatedMemory);
                }

                _loadMemories();
                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Carpeta protegida con éxito')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El PIN debe tener 6 dígitos')),
                );
              }
            },
            child: const Text('Proteger'),
          ),
        ],
      ),
    );
  }

  void _navigateToCreateMemory() {
    const ubicacionPorDefecto = LatLng(0.0, 0.0);

    showDialog(
      context: context,
      builder: (context) => MemoryForm(
        location: ubicacionPorDefecto,
        existingMemory: _selectedCategory != null
            ? Memory(
                id: '',
                title: '',
                description: '',
                date: DateTime.now().toString().split(' ')[0],
                location: {'latitude': 0.0, 'longitude': 0.0},
                category: _selectedCategory!,
              )
            : null,
        onSave: (newMemory) async {
          await _memoryService.saveMemory(newMemory);
          Navigator.pop(context);
          _loadMemories();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _navigateToCreateMemoryInCategory() {
    if (_selectedCategory == null) return;
    _navigateToCreateMemory();
  }

  void _showNewCategoryDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: const Text('Nueva Carpeta',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el nombre de la nueva carpeta:',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Ej: Vacaciones 2024',
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.folder, size: 32),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final newCategory = controller.text.trim();
                          if (newCategory.isNotEmpty) {
                            Provider.of<CategoryProvider>(context,
                                    listen: false)
                                .addCategoryLocally(newCategory);
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Carpeta "$newCategory" creada'),
                                backgroundColor: pinkPrimary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child:
                            const Text('Crear', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShareCategoryDialog(String categoryToShare) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: Text(
            'Compartir "$categoryToShare"',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el correo electrónico del usuario con el que deseas compartir esta carpeta:',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'amigo@correo.com',
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email, size: 32),
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child:
                        const Text('Cancelar', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pinkPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final email = emailController.text.trim();
                      if (email.isNotEmpty) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Compartiendo carpeta con $email...'),
                            backgroundColor: Colors.blueGrey,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        try {
                          await _memoryService.shareCategory(
                              categoryToShare, email);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Carpeta compartida con éxito!'),
                                backgroundColor: pinkPrimary,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      }
                    },
                    child:
                        const Text('Compartir', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
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

  Widget _buildFolderGrid(
    BuildContext context,
    List<String> categories,
    Map<String, List<Memory>> grouped,
    ThemeProvider themeProvider,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No hay carpetas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        final lastMemory = _getLastMemoryForCategory(cat, grouped);
        final isProtected = grouped[cat]
                ?.any((m) => m.hasPassword == true && m.passwordHash != null) ??
            false;

        return GestureDetector(
          onTap: () => _onFolderTap(cat, grouped),
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
                    Icon(
                      Icons.folder,
                      size: 90,
                      color: pinkPrimary.withOpacity(0.8),
                    ),
                    if (lastMemory != null && lastMemory.imageAsset != null)
                      Positioned(
                        top: 30,
                        child: Container(
                          width: 45,
                          height: 35,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
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
                    if (isProtected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: pinkPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 16,
                            color: Colors.white,
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
                    color: themeProvider.isDarkMode
                        ? textDarkMode
                        : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${grouped[cat]?.length ?? 0} recuerdos',
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
        );
      },
    );
  }

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
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
                                color: themeProvider.isDarkMode
                                    ? textDarkMode
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              memory.date.split('T')[0],
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
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
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final categories = categoryProvider.categories;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : Colors.white,
      appBar: AppBar(
        title: Text(
          _selectedCategory ?? 'Mis Carpetas',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: pinkPrimary,
        leading: _selectedCategory != null
            ? IconButton(
                iconSize: 32,
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : null,
        actions: [
          if (_selectedCategory != null)
            IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.lock_outline, color: Colors.white),
              tooltip: 'Proteger esta carpeta con PIN',
              onPressed: () => _showProtectFolderDialog(_selectedCategory!),
            ),
          if (_selectedCategory != null)
            IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.folder_shared, color: Colors.white),
              tooltip: 'Compartir esta carpeta con un usuario',
              onPressed: () => _showShareCategoryDialog(_selectedCategory!),
            ),
          if (_selectedCategory != null)
            IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Agregar recuerdo a esta carpeta',
              onPressed: _navigateToCreateMemoryInCategory,
            ),
          if (_selectedCategory == null)
            IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.create_new_folder, color: Colors.white),
              tooltip: 'Crear nueva carpeta',
              onPressed: _showNewCategoryDialog,
            ),
          IconButton(
            iconSize: 32,
            padding: const EdgeInsets.all(12),
            icon: const Icon(Icons.favorite, color: Colors.white),
            tooltip: 'Ver favoritos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoriteScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: pinkPrimary))
          : _memories.isEmpty
              ? _buildEmptyState(themeProvider)
              : _selectedCategory == null
                  ? _buildFolderGrid(
                      context, categories, groupedMemories, themeProvider)
                  : _buildMemoryList(context,
                      groupedMemories[_selectedCategory] ?? [], themeProvider),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No hay recuerdos aún',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _navigateToCreateMemory,
            style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
            child: const Text('Crear mi primer recuerdo',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}