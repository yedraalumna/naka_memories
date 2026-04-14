import 'package:flutter/foundation.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';

/// Proveedor encargado de gestionar de forma local el estado de los recuerdos
/// marcados como favoritos, manteniéndolos sincronizados con la base de datos
class FavoriteProvider extends ChangeNotifier {
  final MemoryService _memoryService = MemoryService();
  final Set<String> _favoriteIds = {};

  Set<String> get favoriteIds => _favoriteIds;

  /// Verifica si un recuerdo en concreto está en la lista de favoritos
  bool isFavorite(String id) => _favoriteIds.contains(id);

  /// Inicializa el estado cargando los identificadores de los recuerdos
  /// que ya están marcados como favoritos en la base de datos
  void loadFavorites(List<Memory> allMemories) {
    _favoriteIds.clear();
    for (var memory in allMemories) {
      if (memory.isFavorite) {
        _favoriteIds.add(memory.id);
      }
    }
    notifyListeners();
  }

  /// Método que alterna el estado de favorito de un recuerdo
  /// Aplica el cambio en la UI y luego lo sincroniza
  Future<void> toggleFavorite(String id) async {
    final isAdding = !_favoriteIds.contains(id);

    // Se actualiza el estado en la UI instantaneamente
    if (isAdding) {
      _favoriteIds.add(id);
    } else {
      _favoriteIds.remove(id);
    }
    notifyListeners();

    // Se actualiza el estado en la base de datos
    try {
      await _memoryService.updateFavoriteStatus(id, isAdding);
    } catch (e) {
      // Si la base de datos falla, revertimos el cambio visual
      if (isAdding) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
      notifyListeners();

      if (kDebugMode) print('Error actualizando favorito: $e');
    }
  }
}
