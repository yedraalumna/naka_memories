import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/MemoryService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryProvider with ChangeNotifier {
  final MemoryService _memoryService = MemoryService();
  
  List<String> _categories = ['General'];
  bool _isLoading = false;
  
  // Almacena los hashes de las categorías protegidas
  Map<String, String?> _categoryPasswords = {};
  
  // Clave para SharedPreferences
  static const String _passwordsKey = 'category_passwords';

  List<String> get categories => _categories;
  bool get isLoading => _isLoading;

  String? getCategoryHash(String categoryName) {
    return _categoryPasswords[categoryName];
  }

  /// Alias para isCategoryProtected (por si prefieres el nombre más corto)
bool hasPassword(String categoryName) {
  return isCategoryProtected(categoryName);
}

  // Constructor
  CategoryProvider() {
    _loadPasswords(); // Cargar los PINs guardados
    loadCategories();
  }

  Future<void> init() async {
    await _loadPasswords();
    await loadCategories();
  }

  // Cargar los PINs desde SharedPreferences
  Future<void> _loadPasswords() async {
    try {
      // 1) Intentar recuperar desde recuerdos (Supabase + local)
      final fromMemories = await _memoryService.getCategoryPasswordsFromMemories();

      final prefs = await SharedPreferences.getInstance();
      final passwordsJson = prefs.getString(_passwordsKey);
      if (passwordsJson != null) {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(
          jsonDecode(passwordsJson) as Map
        );
        _categoryPasswords = decoded.map((key, value) => MapEntry(key, value as String?));
      }

      // 2) Lo que venga de recuerdos tiene prioridad para sincronizar entre dispositivos
      _categoryPasswords.addAll(fromMemories);
      await _savePasswords();
    } catch (e) {
      print('Error cargando contraseñas: $e');
    }
  }

  /// Verifica si una categoría está protegida con PIN
  bool isCategoryProtected(String categoryName) {
    return _categoryPasswords.containsKey(categoryName) && 
           _categoryPasswords[categoryName] != null &&
           _categoryPasswords[categoryName]!.isNotEmpty;
  }

  /// Obtiene el hash de la contraseña de una categoría
  String? getPasswordHash(String categoryName) {
    return _categoryPasswords[categoryName];
  }

  /// Establece o elimina la protección de una categoría
  Future<void> setCategoryPassword(String categoryName, String? passwordHash) async {
  print('🔐 setCategoryPassword: $categoryName, hash: ${passwordHash != null ? "PROVIDED" : "NULL"}');
  
  if (passwordHash == null || passwordHash.isEmpty) {
    _categoryPasswords.remove(categoryName);
  } else {
    _categoryPasswords[categoryName] = passwordHash;
  }

  // Sincroniza el estado de protección en recuerdos (local + Supabase).
  await _memoryService.applyCategoryPasswordToMemories(categoryName, passwordHash);
  
  print('📝 _categoryPasswords actual: $_categoryPasswords');
  await _savePasswords();
  notifyListeners();
}

  /// CARGAR CATEGORÍAS: Solo trae las que existen en la base de datos
  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final dbCategories = await _memoryService.getAllCategories();
      final Set<String> allCategories = {'General'};
      allCategories.addAll(dbCategories);
      
      List<String> result = allCategories.toList();
      result.sort();
      result.remove('General');
      result.insert(0, 'General');
      
      _categories = result;
    } catch (e) {
      print('Error cargando categorías: $e');
      _categories = ['General'];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// CREAR CATEGORÍA
  Future<void> createCategory(String categoryName, {String? memoryId}) async {
    if (categoryName.isEmpty) return;
    
    try {
      if (!_categories.contains(categoryName)) {
        _categories.add(categoryName);
        _categories.sort();
        _categories.remove('General');
        _categories.insert(0, 'General');
        notifyListeners();
      }
      
      await _memoryService.createCategory(categoryName, memoryId: memoryId);
      await loadCategories(); 
    } catch (e) {
      print('Error creando categoría: $e');
    }
  }

  /// RENOMBRAR CATEGORÍA
  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == 'General' || oldName == newName) return;
    
    try {
      await _memoryService.renameCategory(oldName, newName);
      
      // Actualizar el hash si existe
      if (_categoryPasswords.containsKey(oldName)) {
        final hash = _categoryPasswords[oldName];
        _categoryPasswords.remove(oldName);
        if (hash != null) {
          _categoryPasswords[newName] = hash;
        }
        await _savePasswords();
      }
      
      final index = _categories.indexOf(oldName);
      if (index != -1) {
        _categories[index] = newName;
        _categories.sort();
        _categories.remove('General');
        _categories.insert(0, 'General');
        notifyListeners();
      }
      
      await loadCategories();
    } catch (e) {
      print("Error al renombrar: $e");
      rethrow;
    }
  }

  /// ELIMINAR CATEGORÍA
  Future<void> deleteCategory(String categoryName) async {
    if (categoryName == 'General') {
      throw Exception('No se puede eliminar la categoría "General"');
    }
    
    try {
      await _memoryService.deleteCategory(categoryName);
      
      // Eliminar el hash si existe
      _categoryPasswords.remove(categoryName);
      await _savePasswords();
      
      _categories.remove(categoryName);
      notifyListeners();
      await loadCategories();
    } catch (e) {
      print("Error al borrar categoría: $e");
      rethrow;
    }
  }

  /// RESTAURAR CATEGORÍAS
  Future<void> restoreDefaultCategories() async {
    print("Las categorías predeterminadas fijas han sido desactivadas.");
    await loadCategories();
  }

  /// AÑADIR LOCALMENTE
  void addCategoryLocally(String newCategory) {
    if (newCategory.isEmpty) return;
    if (!_categories.contains(newCategory)) {
      _categories.add(newCategory);
      _categories.sort();
      _categories.remove('General');
      _categories.insert(0, 'General');
      notifyListeners();
    }
  }

  // sincronizar categorías
  Future<void> syncCategories() async {
    await loadCategories();
  }

  // En CategoryProvider - Agrega este método
Future<void> debugPrintAllPasswords() async {
  print('🔐 ==== CATEGORÍAS PROTEGIDAS ====');
  print('Total en memoria: ${_categoryPasswords.length}');
  _categoryPasswords.forEach((key, value) {
    print('   📁 $key: ${value != null ? "HASH: ${value.substring(0, 10)}..." : "SIN HASH"}');
  });
  
  // También verificar en SharedPreferences directamente
  final prefs = await SharedPreferences.getInstance();
  final savedJson = prefs.getString(_passwordsKey);
  print('📦 SharedPreferences: ${savedJson ?? "VACÍO"}');
  print('================================');
}

Future<void> _savePasswords() async {
  try {
    print('💾 Guardando contraseñas: $_categoryPasswords');
    final prefs = await SharedPreferences.getInstance();
    final passwordsJson = jsonEncode(_categoryPasswords);
    await prefs.setString(_passwordsKey, passwordsJson);
    print('✅ Contraseñas guardadas correctamente');
  } catch (e) {
    print('❌ Error guardando contraseñas: $e');
  }
}
}