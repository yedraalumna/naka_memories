import 'package:flutter/material.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';

class FavoriteProvider extends ChangeNotifier {
  final MemoryService _memoryService = MemoryService();
  final Set<String> _favoriteIds = {};

  Set<String> get favoriteIds => _favoriteIds;

  bool isFavorite(String id) => _favoriteIds.contains(id);

  // Inicializa el provider y carga los datos desde la BD
  Future<void> loadFavorites(List<Memory> allMemories) async {
    _favoriteIds.clear();
    for (var memory in allMemories) {
      if (memory.isFavorite) {
        _favoriteIds.add(memory.id);
      }
    }
    notifyListeners();
  }

  // Alternar favorito: UI instantánea + BD real
  Future<void> toggleFavorite(String id) async {
    final isAdding = !_favoriteIds.contains(id);

    // UI Instantánea
    if (isAdding) {
      _favoriteIds.add(id);
    } else {
      _favoriteIds.remove(id);
    }
    notifyListeners();

    // Persistencia Real en Supabase (usando el campo isFavorite del modelo)
    await _memoryService.updateFavoriteStatus(id, isAdding);
  }
}
