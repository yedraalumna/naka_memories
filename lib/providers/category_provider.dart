import 'package:flutter/material.dart';
import '../models/Memory.dart';
import '../services/MemoryService.dart';

class CategoryProvider with ChangeNotifier {
  final MemoryService _memoryService = MemoryService();
  
  List<String> _categories = [];
  bool _isLoading = false;

  List<String> get categories => _categories;
  bool get isLoading => _isLoading;

  // Categorías predeterminadas
  static const List<String> defaultCategories = [
    'General',
    'Viajes',
    'Amigos',
    'Familia',
    'Comida',
    'Estudio',
  ];

  // Constructor
  CategoryProvider() {
    loadCategories();
  }

  // Cargar categorías desde MemoryService
  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Obtener categorías existentes de los recuerdos
      final categoriesFromDb = await _memoryService.getAllCategories();
      
      // Asegurar que las categorías predeterminadas estén presentes
      final Set<String> uniqueCategories = Set<String>.from(categoriesFromDb);
      
      for (var defaultCat in defaultCategories) {
        if (!uniqueCategories.contains(defaultCat)) {
          uniqueCategories.add(defaultCat);
        }
      }
      
      _categories = uniqueCategories.toList();
      _categories.sort();
      
      // Asegurar que "General" sea la primera
      _categories.remove('General');
      _categories.insert(0, 'General');
      
    } catch (e) {
      print('Error cargando categorías: $e');
      _categories = List.from(defaultCategories);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Crear nueva categoría
  Future<void> createCategory(String categoryName, {String? memoryId}) async {
    if (categoryName.isEmpty) return;
    if (_categories.contains(categoryName)) return;
    
    try {
      await _memoryService.createCategory(categoryName, memoryId: memoryId);
      await loadCategories(); // Recargar después de crear
    } catch (e) {
      print('Error creando categoría: $e');
      // Fallback: añadir localmente
      addCategoryLocally(categoryName);
      rethrow;
    }
  }

  // Renombrar categoría
  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == newName) return;
    if (oldName.isEmpty || newName.isEmpty) return;
    if (oldName == 'General') {
      throw Exception('No se puede renombrar la categoría "General"');
    }
    
    try {
      await _memoryService.renameCategory(oldName, newName);
      await loadCategories(); // Recargar después de renombrar
    } catch (e) {
      print('Error renombrando categoría: $e');
      rethrow;
    }
  }

  // Eliminar categoría
  Future<void> deleteCategory(String categoryName) async {
    if (categoryName == 'General') {
      throw Exception('No se puede eliminar la categoría "General"');
    }
    
    try {
      await _memoryService.deleteCategory(categoryName);
      await loadCategories(); // Recargar después de eliminar
    } catch (e) {
      print('Error eliminando categoría: $e');
      rethrow;
    }
  }

  // Restaurar categorías predeterminadas
  Future<void> restoreDefaultCategories() async {
    try {
      await _memoryService.restoreDefaultCategories();
      await loadCategories();
    } catch (e) {
      print('Error restaurando categorías: $e');
      rethrow;
    }
  }

  // Añadir categoría localmente (para UI rápida)
  void addCategoryLocally(String newCategory) {
    if (!_categories.contains(newCategory)) {
      _categories.add(newCategory);
      _categories.sort();
      // Asegurar que "General" sea la primera
      _categories.remove('General');
      _categories.insert(0, 'General');
      notifyListeners();
    }
  }

  // Sincronizar con cambios externos
  Future<void> syncCategories() async {
    await loadCategories();
  }
}