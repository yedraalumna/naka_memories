import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/MemoryService.dart';

/// Proveedor encargado de gestionar el estado y la lógica de las categorías
/// Además de manejar la creación, edición, eliminación y el sistema de protección por PIN de dichas categorías
class CategoryProvider with ChangeNotifier {
  final MemoryService _memoryService = MemoryService();

  List<String> _categories = ['General'];
  bool _isLoading = false;

  /// Almacena los hashes de las contraseñas de cada categoría protegida
  Map<String, String?> _categoryPasswords = {};

  /// Clave utilizada para guardar y recuperar los PINs en el almacenamiento local
  static const String _passwordsKey = 'category_passwords';

  List<String> get categories => _categories;
  bool get isLoading => _isLoading;

  CategoryProvider() {
    init();
  }

  /// Inicializa el estado cargando los PINs guardados y las categorías existentes
  Future<void> init() async {
    await _loadPasswords();
    await loadCategories();
  }

  /// Verifica si una categoría tiene pin (Alias de isCategoryProtected)
  bool hasPassword(String categoryName) {
    return isCategoryProtected(categoryName);
  }

  /// Verifica si una categoría tiene PIN
  bool isCategoryProtected(String categoryName) {
    return _categoryPasswords.containsKey(categoryName) &&
        _categoryPasswords[categoryName] != null &&
        _categoryPasswords[categoryName]!.isNotEmpty;
  }

  /// Obtiene el hash de la contraseña de una categoría
  String? getPasswordHash(String categoryName) {
    return _categoryPasswords[categoryName];
  }

  /// Método que recupera los PINs guardados, combinando los datos locales con los sincronizados
  Future<void> _loadPasswords() async {
    try {
      // Recuperar desde recuerdos (Supabase + local)
      final fromMemories =
          await _memoryService.getCategoryPasswordsFromMemories();

      final prefs = await SharedPreferences.getInstance();
      final passwordsJson = prefs.getString(_passwordsKey);

      if (passwordsJson != null) {
        final Map<String, dynamic> decoded =
            Map<String, dynamic>.from(jsonDecode(passwordsJson) as Map);
        _categoryPasswords =
            decoded.map((key, value) => MapEntry(key, value as String?));
      }

      // Lo que venga de recuerdos tiene prioridad para sincronizar entre dispositivos
      _categoryPasswords.addAll(fromMemories);
      await _savePasswords();
    } catch (e) {
      if (kDebugMode) print('Error cargando contraseñas: $e');
    }
  }

  /// Métodos que guarda el estado actual de las contraseñas en el almacenamiento local
  Future<void> _savePasswords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordsJson = jsonEncode(_categoryPasswords);
      await prefs.setString(_passwordsKey, passwordsJson);
    } catch (e) {
      if (kDebugMode) print('Error guardando contraseñas: $e');
    }
  }

  /// Método que establece o elimina la protección por PIN de una categoría
  /// Si el hash es null o vacío, se elimina la protección
  Future<void> setCategoryPassword(
      String categoryName, String? passwordHash) async {
    if (passwordHash == null || passwordHash.isEmpty) {
      _categoryPasswords.remove(categoryName);
    } else {
      _categoryPasswords[categoryName] = passwordHash;
    }

    // Sincroniza el estado de protección en la base de datos y de forma local
    await _memoryService.applyCategoryPasswordToMemories(
        categoryName, passwordHash);

    await _savePasswords();
    notifyListeners();
  }

  /// Obtiene las categorías desde la base de datos y las ordena,
  /// manteniendo siempre "General" en la primera posición
  Future<void> loadCategories() async {
    _isLoading = true;

    // Retraso de microsegundos para asegurar que el estado de carga se actualice
    Future.microtask(() => notifyListeners());

    try {
      // solo traemos las categorías de la base de datos
      final dbCategories = await _memoryService.getAllCategories();

      // Aseguramos que 'General' siempre esté presente
      final Set<String> allCategories = {'General'};
      allCategories.addAll(dbCategories);

      List<String> result = allCategories.toList();
      result.sort();
      result.remove('General');
      result.insert(0, 'General');

      _categories = result;
      if (kDebugMode) print('Categorías cargadas desde BD: $_categories');
    } catch (e) {
      if (kDebugMode) print('Error cargando categorías: $e');
      _categories = ['General'];
    } finally {
      _isLoading = false;
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  /// Crea una nueva categoría y la sincroniza con la base de datos
  Future<void> createCategory(String categoryName, {String? memoryId}) async {
    if (categoryName.isEmpty) return;

    try {
      // Actualización local inmediata para que sea fluida, luego se sincroniza con la base de datos
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
      if (kDebugMode) print('Error creando categoría: $e');
    }
  }

  /// Método que restaura las carpetas predeterminadas
  Future<void> restoreDefaultCategories() async {
    if (kDebugMode) print('Restaurando carpetas predeterminadas');

    final List<String> defaultCategories = [
      'Viajes',
      'Amigos',
      'Familia',
      'Comida',
      'Estudio'
    ];

    try {
      // Obtenemos las categorías actuales de la BD
      final dbCategories = await _memoryService.getAllCategories();

      for (var category in defaultCategories) {
        // Verificamos si la categoría ya existe en la base de datos, no en la lista local
        if (dbCategories.contains(category) == false) {
          await _memoryService.createCategory(category);
        if (kDebugMode) print('Categoría creada: $category');
        } else {
        if (kDebugMode) print('La categoría $category ya existe en BD');
        }
      }

      // Recargamos las categorías
      await loadCategories();
      if (kDebugMode) print('Carpetas predeterminadas restauradas correctamente');
    } catch (e) {
      if (kDebugMode) print('Error al restaurar: $e');
      rethrow;
    }
  }

  /// Método que cambia el nombre de una categoría existente
  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == 'General' || oldName == newName) return;

    try {
      await _memoryService.renameCategory(oldName, newName);

      // Actualizamos la clave del hash si la categoría estaba protegida
      if (_categoryPasswords.containsKey(oldName)) {
        final hash = _categoryPasswords[oldName];
        _categoryPasswords.remove(oldName);
        if (hash != null) {
          _categoryPasswords[newName] = hash;
        }
        await _savePasswords();
      }

      // Actualización local
      final index = _categories.indexOf(oldName);
      if (index != -1) {
        _categories[index] = newName;
        _categories.sort();
        _categories.remove('General');
        _categories.insert(0, 'General');
        notifyListeners();
      }

      // Aseguramos sincronización completa
      await loadCategories();
    } catch (e) {
      if (kDebugMode) print("Error al renombrar categoría: $e");
      rethrow;
    }
  }

  /// Método que elimina una categoría y su contraseña (si tiene)
  Future<void> deleteCategory(String categoryName) async {
    if (categoryName == 'General') {
      throw Exception('No se puede eliminar la categoría "General"');
    }

    try {
      await _memoryService.deleteCategory(categoryName);

      // Limpiar protección si existía
      _categoryPasswords.remove(categoryName);
      await _savePasswords();

      _categories.remove(categoryName);
      notifyListeners();
      await loadCategories();
    } catch (e) {
      if (kDebugMode) print("Error al borrar categoría: $e");
      rethrow;
    }
  }

  /// Añade una categoría al estado local sin enviar petición al servidor/bd de inmediato
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

  /// Método que obliga a recargar las categorías desde la base de datos
  Future<void> syncCategories() async {
    await loadCategories();
  }
}
