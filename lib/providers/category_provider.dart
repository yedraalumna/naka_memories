import 'package:flutter/material.dart';
import '../models/Memory.dart';
import '../services/MemoryService.dart';

class CategoryProvider with ChangeNotifier {
  final MemoryService _memoryService = MemoryService();
  
  // Empezamos con la lista por defecto
  List<String> _categories = List.from(Memory.categoriesList);
  bool _isLoading = false;

  List<String> get categories => _categories;
  bool get isLoading => _isLoading;

  // Método para cargar y extraer categorías únicas de la base de datos
  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      final memories = await _memoryService.getMemories();
      
      // 1. Empezamos con las categorías por defecto en un Set para evitar duplicados
      final Set<String> uniqueCategories = Set.from(Memory.categoriesList);
      
      // 2. Añadimos las categorías de los recuerdos del usuario
      for (var memory in memories) {
        if (memory.category.isNotEmpty && memory.category != 'Sin categoría') {
          uniqueCategories.add(memory.category);
        }
      }

      // 3. Actualizamos nuestra lista
      _categories = uniqueCategories.toList();
      
      // Opcional: Ordenar alfabéticamente (manteniendo 'General' primero si quieres)
      // _categories.sort();
      
    } catch (e) {
      print('Error cargando categorías: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Método para añadir una nueva categoría localmente (para que la UI se actualice rápido)
  void addCategoryLocally(String newCategory) {
    if (!_categories.contains(newCategory)) {
      _categories.add(newCategory);
      notifyListeners();
    }
  }
}