import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/Memory.dart';
import '../services/MemoryService.dart';
import '../providers/favorite_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import '../widget/MemoryListTile.dart';
import 'coordinate_input_screen.dart'; // Importa esto para la edición

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

  void _loadMemories() {
    setState(() {
      _memoriesFuture = _memoryService.getMemories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = context.watch<FavoriteProvider>().favoriteIds;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : Colors.white,
      appBar: AppBar(
        title: Text(
          'Mis Favoritos',
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
      body: favoriteIds.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    'Aún no tienes favoritos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : FutureBuilder<List<Memory>>(
              future: _memoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: pinkPrimary));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text('No hay recuerdos disponibles.',
                        style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey)),
                  );
                }

                final favoriteMemories = snapshot.data!
                    .where((memory) => favoriteIds.contains(memory.id))
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: favoriteMemories.length,
                  itemBuilder: (context, index) {
                    final memory = favoriteMemories[index];
                    return MemoryListTile(
                      memory: memory,
                      // --- LÓGICA DE EDICIÓN ---
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
                          _loadMemories(); // Recarga la lista
                        }
                      },
                      // --- LÓGICA DE BORRADO ---
                      onDelete: () async {
                        await _memoryService.deleteMemory(memory.id);
                        Navigator.pop(context);
                        _loadMemories(); // Recarga la lista
                      },
                      // --- LÓGICA DE ACTUALIZACIÓN ---
                      onUpdate: (updatedMemory) async {
                        await _memoryService.saveMemory(updatedMemory);
                        _loadMemories(); // Recarga la lista
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
