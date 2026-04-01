import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/Memory.dart';
import 'package:uuid/uuid.dart';

class MemoryService {
  static const String _memoriesKey = 'nayeka memories';
  static const String _storageBucket = 'nayeka memories';
  static const String _customCategoriesKey = 'custom_categories';
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  String _generateId() {
    return _uuid.v4();
  }

  /// Obtiene la URL pública de un archivo en el bucket de almacenamiento
  String getPublicUrl(String path) {
    try {
      return _supabase.storage.from(_storageBucket).getPublicUrl(path);
    } catch (e) {
      print('Error obteniendo URL pública: $e');
      return '';
    }
  }

  // Método helper para obtener URL pública con cache buster
  String _getPublicUrlWithCacheBuster(String path) {
    try {
      final publicUrl = getPublicUrl(path);
      return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Error obteniendo URL pública con cache buster: $e');
      return '';
    }
  }

  Future<String?> uploadAvatar(Uint8List bytes, String userId) async {
    try {
      print('Subiendo avatar para usuario: $userId');

      final String fileName = 'avatar_$userId.jpg';
      final String path = 'avatars/$fileName';

      await _supabase.storage.from(_storageBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final String cacheBusterUrl = _getPublicUrlWithCacheBuster(path);
      print('Avatar subido exitosamente: $cacheBusterUrl');
      return cacheBusterUrl;
    } catch (e) {
      print('Error subiendo avatar: $e');
      return null;
    }
  }

  // obtenemos los recuerdos - AHORA SIEMPRE USA SUPABASE SI HAY USUARIO
  Future<List<Memory>> getMemories() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        try {
          print('Intentando obtener de Supabase para usuario: ${user.id}');
          final supabaseMemories = await _getMemoriesFromSupabase();

          if (supabaseMemories.isNotEmpty) {
            print('${supabaseMemories.length} recuerdos cargados de Supabase');
            await _syncLocalWithSupabase(supabaseMemories);
            return supabaseMemories;
          }
        } catch (e) {
          print('Error obteniendo de Supabase: $e');
        }
      }

      print('Cargando desde almacenamiento local...');
      return await _getMemoriesFromLocal();
    } catch (e) {
      print('Error general obteniendo recuerdos: $e');
      return [];
    }
  }

  // Sincronizar almacenamiento local con Supabase
  Future<void> _syncLocalWithSupabase(List<Memory> supabaseMemories) async {
    try {
      final localMemories = await _getMemoriesFromLocal();
      final prefs = await SharedPreferences.getInstance();

      // Crear mapa de memorias de Supabase por ID
      final Map<String, Memory> supabaseMap = {
        for (var m in supabaseMemories) m.id: m
      };

      // Combinar memorias
      final Set<String> allIds = {
        ...supabaseMap.keys,
        ...localMemories.map((m) => m.id)
      };
      final List<Memory> mergedMemories = [];

      for (final id in allIds) {
        if (supabaseMap.containsKey(id)) {
          mergedMemories.add(supabaseMap[id]!);
        } else {
          final localMemory = localMemories.firstWhere((m) => m.id == id);
          mergedMemories.add(localMemory);
        }
      }

      // Guardar versión sincronizada localmente
      final memoriesJson =
          mergedMemories.map((m) => jsonEncode(m.toMap())).toList();
      await prefs.setStringList(_memoriesKey, memoriesJson);

      print(
          'Sincronización local completada: ${mergedMemories.length} recuerdos');
    } catch (e) {
      print('Error sincronizando con local: $e');
    }
  }

  // Obtener recuerdos de Supabase (Propios y Compartidos)
  Future<List<Memory>> _getMemoriesFromSupabase() async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      final userEmail = user
          ?.email; // Necesitamos el correo para saber qué nos han compartido

      if (userId == null) {
        print('Usuario no autenticado en Supabase');
        return [];
      }

      print(
          'Buscando recuerdos para usuario: $userId o compartidos con: $userEmail');

      // 🔥 ARREGLO 1: Quitadas las comillas dobles de $userEmail para que coincida en Supabase 🔥
      final response = await _supabase
          .from('nayeka memories')
          .select()
          .or('user_id.eq.$userId,shared_with.cs.{$userEmail}')
          .order('date', ascending: false);

      final List<Memory> memories = [];

      print('${response.length} registros encontrados en Supabase');

      for (var item in response) {
        try {
          final memory = Memory.fromMap(item);
          memories.add(memory);
        } catch (e) {
          print('Error procesando item: $e');
        }
      }

      return memories;
    } catch (e) {
      print('Error en _getMemoriesFromSupabase: $e');
      return [];
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Compartir todos los recuerdos de una categoría con un correo
  Future<void> shareCategory(String category, String emailToShare) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || emailToShare.isEmpty) return;

      // Llamamos a la función SQL que verifica si el correo existe en Supabase
      final bool userExists = await _supabase.rpc(
        'check_user_exists',
        params: {'search_email': emailToShare},
      );

      // Si no existe, cortamos el proceso y lanzamos un mensaje limpio
      if (!userExists) {
        throw 'No hay ninguna cuenta registrada con el correo:\n$emailToShare';
      }

      // 2. Si existe, obtenemos solo los recuerdos de ESA carpeta que sean del propio usuario
      final response = await _supabase
          .from('nayeka memories')
          .select()
          .eq('user_id', user.id)
          .eq('category', category);

      // Iteramos para añadir el correo
      for (var item in response) {
        List<String> currentShared = [];
        if (item['shared_with'] != null) {
          currentShared =
              List<String>.from(item['shared_with'].map((e) => e.toString()));
        }

        // Si el email no está ya en la lista, lo añadimos y actualizamos
        if (!currentShared.contains(emailToShare)) {
          currentShared.add(emailToShare);

          await _supabase
              .from('nayeka memories')
              .update({'shared_with': currentShared}).eq('id', item['id']);
        }
      }
    } catch (e) {
      print('Error compartiendo carpeta internamente: $e');
      // Lanzamos el error exacto (limpiando la palabra Exception si aparece)
      throw e.toString().replaceAll('Exception: ', '');
    }
  }

  // Obtener recuerdos de almacenamiento local
  Future<List<Memory>> _getMemoriesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoriesJson = prefs.getStringList(_memoriesKey) ?? [];
      print('${memoriesJson.length} recuerdos en almacenamiento local');

      final List<Memory> memories = [];

      for (final json in memoriesJson) {
        try {
          final map = jsonDecode(json);
          memories.add(Memory.fromMap(map));
        } catch (e) {
          print('Error parseando memoria local: $e');
        }
      }

      return memories;
    } catch (e) {
      print('Error en _getMemoriesFromLocal: $e');
      return [];
    }
  }

  // subir imagen a Supabase
  Future<String?> uploadImage(Uint8List imageBytes) async {
    try {
      if (imageBytes.isEmpty) {
        print('Bytes de imagen vacíos');
        return null;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Usuario no autenticado para subir imagen');
        return null;
      }

      // Generamos un nombre único para el archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = _uuid.v4().substring(0, 8);
      final fileName = '${userId}_${timestamp}_$random.jpg';
      final path = 'memories/$fileName';

      print('Subiendo imagen: $path (${imageBytes.length} bytes)');

      // Subida a Supabase Storage
      await _supabase.storage.from(_storageBucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
              upsert: false,
            ),
          );

      print('Imagen subida exitosamente a Storage');

      // Obtener URL pública con cache buster
      final String cacheBusterUrl = _getPublicUrlWithCacheBuster(path);

      print('URL final generada: $cacheBusterUrl');
      return cacheBusterUrl;
    } catch (e) {
      print('Error general subiendo imagen: $e');

      if (e is StorageException) {
        print('Detalles del error de Storage:');
        print('Código: ${e.statusCode}');
        print('Mensaje: ${e.message}');

        if (e.statusCode == '404') {
          print('Error: El bucket "$_storageBucket" no existe.');
          print('Crea el bucket en Supabase Dashboard > Storage');
        }
      }
      return null;
    }
  }

  // 🔥 ARREGLO 2: Función de Herencia de Permisos 🔥
  Future<Memory> _inheritSharedUsers(Memory memory) async {
    if (memory.category == 'Sin categoría' || memory.category.isEmpty) {
      return memory;
    }
    try {
      final localMemories = await _getMemoriesFromLocal();
      final categoryMemories =
          localMemories.where((m) => m.category == memory.category).toList();

      Set<String> allSharedEmails = {...memory.sharedWith};
      for (var m in categoryMemories) {
        if (m.sharedWith.isNotEmpty) {
          allSharedEmails.addAll(m.sharedWith);
        }
      }
      return memory.copyWith(sharedWith: allSharedEmails.toList());
    } catch (e) {
      print('Error heredando usuarios: $e');
      return memory;
    }
  }

  // Guardamos el recuerdo con imagen
  Future<String> saveMemoryWithImage({
    required Memory memory,
    required Uint8List imageBytes,
  }) async {
    print('Guardando recuerdo con imagen');

    try {
      final memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      print('ID generado para memoria: $memoryId');

      String? imageUrl;
      final user = _supabase.auth.currentUser;

      if (user != null) {
        print('Intentando subir imagen a Supabase');
        imageUrl = await uploadImage(imageBytes);
        if (imageUrl != null) {
          print('Imagen subida: $imageUrl');
        } else {
          print('No se pudo subir la imagen');
        }
      } else {
        print('Sin usuario autenticado, omitiendo subida de imagen');
      }

      Memory finalMemory = memory.copyWith(
        id: memoryId,
        imageAsset: imageUrl,
      );

      // 🔥 Aplicamos la herencia 🔥
      finalMemory = await _inheritSharedUsers(finalMemory);

      await _saveMemoryToLocal(finalMemory);
      print('Memoria guardada localmente: $memoryId');

      if (user != null) {
        try {
          await _saveMemoryToSupabase(finalMemory);
          print('Memoria guardada en Supabase: $memoryId');
        } catch (e) {
          print('Error guardando en Supabase, pero guardado localmente: $e');
        }
      }
      return memoryId;
    } catch (e) {
      print('Error en saveMemoryWithImage: $e');
      rethrow;
    }
  }

  // Método específico para subir video a Supabase
  Future<String?> uploadVideo(Uint8List videoBytes) async {
    try {
      if (videoBytes.isEmpty) return null;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = _uuid.v4().substring(0, 8);
      final fileName = '${userId}_${timestamp}_$random.mp4';
      final path = 'videos/$fileName';

      print('Subiendo video: $path (${videoBytes.length} bytes)');

      // Subida usando uploadBinary
      await _supabase.storage.from(_storageBucket).uploadBinary(
            path,
            videoBytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Obtener URL pública con cache buster
      final String cacheBusterUrl = _getPublicUrlWithCacheBuster(path);

      print('Video subido: $cacheBusterUrl');
      return cacheBusterUrl;
    } catch (e) {
      print('Error subiendo video: $e');
      return null;
    }
  }

  // Guardar recuerdo con video
  Future<Memory> saveMemoryWithVideo({
    required Memory memory,
    required Uint8List videoBytes,
  }) async {
    print('Guardando recuerdo con video...');

    try {
      final memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      String? videoUrl;

      final user = _supabase.auth.currentUser;

      if (user != null) {
        videoUrl = await uploadVideo(videoBytes);
      }

      Memory finalMemory = memory.copyWith(
        id: memoryId,
        imageAsset: videoUrl,
      );

      // 🔥 Aplicamos la herencia 🔥
      finalMemory = await _inheritSharedUsers(finalMemory);

      await _saveMemoryToLocal(finalMemory);
      print('Memoria (video) guardada localmente: $memoryId');

      if (user != null) {
        try {
          await _saveMemoryToSupabase(finalMemory);
          print('Memoria (video) guardada en Supabase: $memoryId');
        } catch (e) {
          print('Error guardando en Supabase, pero guardado localmente: $e');
        }
      }

      return finalMemory;
    } catch (e) {
      print('Error en saveMemoryWithVideo: $e');
      rethrow;
    }
  }

  // Guardar recuerdo en Supabase
  Future<void> _saveMemoryToSupabase(Memory memory) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      if (memory.id.isEmpty) {
        throw Exception('ID de memoria no puede estar vacío');
      }

      print('Guardando en Supabase: ${memory.id}');

      final memoryData = {
        'id': memory.id,
        'user_id': userId,
        'title': memory.title,
        'description': memory.description,
        'date': memory.date,
        'latitude': memory.latitude,
        'longitude': memory.longitude,
        'imageAsset': memory.imageAsset,
        'category': memory.category,
        'isFavorite': memory.isFavorite,
        'shared_with': memory.sharedWith,
        'has_password': memory.hasPassword,
        'password_hash': memory.passwordHash,
      };

      print('Datos a guardar: $memoryData');

      await _supabase
          .from('nayeka memories')
          .upsert(memoryData, onConflict: 'id');

      print('Recuerdo guardado en Supabase: ${memory.id}');
    } catch (e) {
      print('Error guardando en Supabase: $e');
      throw Exception('Error al guardar en la nube: $e');
    }
  }

  // Guardamos en local
  Future<void> _saveMemoryToLocal(Memory memory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Memory> memories = await _getMemoriesFromLocal();

      final String memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      final finalMemory = memory.copyWith(id: memoryId);

      final existingIndex = memories.indexWhere((m) => m.id == memoryId);

      if (existingIndex >= 0) {
        memories[existingIndex] = finalMemory;
        print('Actualizando memoria local: $memoryId');
      } else {
        memories.add(finalMemory);
        print('Agregando nueva memoria local: $memoryId');
      }

      final memoriesJson = memories.map((m) => jsonEncode(m.toMap())).toList();
      await prefs.setStringList(_memoriesKey, memoriesJson);

      print('Total de recuerdos locales: ${memories.length}');
    } catch (e) {
      print('Error guardando localmente: $e');
      throw Exception('Error al guardar localmente: $e');
    }
  }

  // Guardamos recuerdo sin imagen
  Future<void> saveMemory(Memory memory) async {
    try {
      print('Guardando recuerdo: ${memory.id}');

      final memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      Memory finalMemory = memory.copyWith(id: memoryId);

      // 🔥 Aplicamos la herencia 🔥
      finalMemory = await _inheritSharedUsers(finalMemory);

      await _saveMemoryToLocal(finalMemory);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _saveMemoryToSupabase(finalMemory);
      }

      print('Recuerdo guardado exitosamente: $memoryId');
    } catch (e) {
      print('Error guardando recuerdo: $e');
      rethrow;
    }
  }

  Future<void> updateFavoriteStatus(String memoryId, bool isFavorite) async {
    try {
      // 1. Actualizar en Almacenamiento Local
      final prefs = await SharedPreferences.getInstance();
      final memories = await _getMemoriesFromLocal();

      final index = memories.indexWhere((m) => m.id == memoryId);
      if (index >= 0) {
        memories[index] = memories[index].copyWith(isFavorite: isFavorite);
        final memoriesJson =
            memories.map((m) => jsonEncode(m.toMap())).toList();
        await prefs.setStringList(_memoriesKey, memoriesJson);
        print('Estado de favorito actualizado localmente: $isFavorite');
      }

      // 2. Actualizar en Supabase
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final userId = user.id;
        await _supabase
            .from('nayeka memories')
            .update({'isFavorite': isFavorite})
            .eq('id', memoryId)
            .eq('user_id', userId);
        print('Favorito actualizado en Supabase: $memoryId -> $isFavorite');
      }
    } catch (e) {
      print('Error actualizando estado de favorito: $e');
    }
  }

  // Método para verificar y crear bucket
  Future<void> verifyStorageBucket() async {
    try {
      print('Verificando bucket de Storage...');

      try {
        final files = await _supabase.storage.from(_storageBucket).list();
        print('Bucket "$_storageBucket" accesible');
        print('Archivos en bucket: ${files.length}');

        // Verificar carpetas
        final folders = ['avatars', 'memories', 'videos'];
        for (final folder in folders) {
          try {
            final contents =
                await _supabase.storage.from(_storageBucket).list(path: folder);
            print('Carpeta $folder encontrada: ${contents.length} archivos');
          } catch (e) {
            print(
                'La carpeta "$folder" se creará automáticamente al subir archivos');
          }
        }
      } catch (e) {
        if (e is StorageException && e.message.contains('not found')) {
          print('El bucket "$_storageBucket" no existe');
          print('Ve a Supabase Dashboard > Storage y:');
          print('1. Click en "Create a new bucket"');
          print('2. Nombre: "$_storageBucket"');
          print('3. Marca "Make it public"');
          print('4. Click "Create bucket"');
        } else {
          print('Error accediendo al bucket: $e');
        }
      }
    } catch (e) {
      print('Error verificando bucket: $e');
    }
  }

  // Método completo de prueba
  Future<void> testSupabaseConnection() async {
    try {
      print('PRUEBA COMPLETA DE SUPABASE 🧪');
      print('=' * 50);

      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('Usuario no autenticado');
        return;
      }
      print('Usuario autenticado: ${user.id}');

      // 1. Verificar tabla
      print('\nVerificamos la tabla "nayeka memories"...');
      try {
        final response = await _supabase
            .from('nayeka memories')
            .select('id')
            .eq('user_id', user.id)
            .limit(1);

        if (response != null) {
          print('Tabla accesible');
        }
      } catch (e) {
        print('Error accediendo a tabla: $e');
        print('''
          CREATE TABLE "nayeka memories" (  
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            date TEXT NOT NULL,
            latitude TEXT,
            longitude TEXT,
            imageAsset TEXT,
            category TEXT,
            isFavorite BOOLEAN DEFAULT FALSE,
            cookies_accepted BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );
        ''');
      }

      // 2. Verificar Storage
      print('\nVerificando storage...');
      await verifyStorageBucket();

      print('\n' + '=' * 50);
      print('Prueba completa');
    } catch (e) {
      print('Error en testSupabaseConnection: $e');
    }
  }

  // Eliminar recuerdo
  Future<void> deleteMemory(String id) async {
    try {
      print('Eliminando recuerdo: $id');
      await _deleteMemoryFromLocal(id);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _deleteMemoryFromSupabase(id);
      }
    } catch (e) {
      print('Error eliminando recuerdo: $e');
    }
  }

  Future<void> _deleteMemoryFromLocal(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memories = await _getMemoriesFromLocal();

      final updatedMemories = memories.where((m) => m.id != id).toList();
      final memoriesJson =
          updatedMemories.map((m) => jsonEncode(m.toMap())).toList();

      await prefs.setStringList(_memoriesKey, memoriesJson);
      print('Recuerdo eliminado localmente: $id');
      print('Recuerdos restantes: ${updatedMemories.length}');
    } catch (e) {
      print('Error eliminando localmente: $e');
    }
  }

  Future<void> _deleteMemoryFromSupabase(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('nayeka memories')
            .delete()
            .eq('id', id)
            .eq('user_id', userId);
        print('Recuerdo eliminado de Supabase: $id');
      }
    } catch (e) {
      print('Error eliminando de Supabase: $e');
    }
  }

  // Limpiar todos los recuerdos
  Future<void> clearAllMemories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_memoriesKey);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _clearAllMemoriesFromSupabase();
      }

      print('Todos los recuerdos eliminados');
    } catch (e) {
      print('Error limpiando recuerdos: $e');
    }
  }

  Future<void> _clearAllMemoriesFromSupabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('nayeka memories').delete().eq('user_id', userId);

        print('Todos los recuerdos eliminados de Supabase');
      }
    } catch (e) {
      print('Error limpiando Supabase: $e');
    }
  }

  /// Obtiene todas las categorías únicas de los recuerdos
  // 1. Obtener categorías REALES (solo las que tienen recuerdos)
  // ============ GESTIÓN DE CARPETAS (ÚNICA VERSIÓN) ============

  // Obtiene solo las categorías que tienen recuerdos reales + General
  Future<List<String>> getAllCategories() async {
    try {
      final user = _supabase.auth.currentUser;
      Set<String> uniqueCategories = {'General'};

      // 1. Obtener categorías de recuerdos reales
      if (user != null) {
        final userEmail = user.email; // Necesitamos el correo para la consulta

        final response = await _supabase
            .from('nayeka memories')
            .select('category')
            .or('user_id.eq.${user.id},shared_with.cs.{$userEmail}');

        for (var item in response) {
          final cat = item['category'] as String?;
          if (cat != null && cat.trim().isNotEmpty) uniqueCategories.add(cat);
        }
      } else {
        final localMemories = await _getMemoriesFromLocal();
        for (var m in localMemories) {
          uniqueCategories.add(m.category);
        }
      }

      // 2. Añadir categorías personalizadas guardadas en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
      uniqueCategories.addAll(customCategories);

      List<String> result = uniqueCategories.toList();
      result.sort();
      return result;
    } catch (e) {
      return ['General'];
    }
  }

  // En MemoryService.dart// En MemoryService.dart
  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == 'General' || oldName == newName) return;

    try {
      // 1. Actualizar recuerdos reales en Supabase
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('nayeka memories')
            .update({'category': newName})
            .eq('category', oldName)
            .eq('user_id', user.id);
      }

      // 2. Actualizar recuerdos locales
      final prefs = await SharedPreferences.getInstance();
      final memories = await _getMemoriesFromLocal();
      final updated = memories.map((m) {
        return m.category == oldName ? m.copyWith(category: newName) : m;
      }).toList();
      await prefs.setStringList(
          _memoriesKey, updated.map((m) => jsonEncode(m.toMap())).toList());

      // 3. Actualizar en SharedPreferences (categorías personalizadas)
      final customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
      if (customCategories.contains(oldName)) {
        customCategories.remove(oldName);
        customCategories.add(newName);
        await prefs.setStringList(_customCategoriesKey, customCategories);
      }

      print('✅ Categoría renombrada: $oldName → $newName');
    } catch (e) {
      print('❌ Error renombrando categoría: $e');
      throw Exception('No se pudo renombrar la categoría: $e');
    }
  }

  // Lo dejamos vacío para que no haga NADA
  Future<void> restoreDefaultCategories() async {
    // Vacío para que no cree carpetas automáticamente
    return;
  }

  /// Crear una nueva categoría (opcionalmente asignada a un recuerdo)
  Future<void> createCategory(String categoryName, {String? memoryId}) async {
    if (categoryName.isEmpty) return;

    try {
      if (memoryId != null) {
        // Asignar a un recuerdo existente
        final memory = await _getMemoryById(memoryId);
        if (memory != null) {
          final updatedMemory = memory.copyWith(category: categoryName);
          await saveMemory(updatedMemory);
          print('Categoría "$categoryName" asignada al recuerdo $memoryId');
        }
      } else {
        // Guardar la categoría en SharedPreferences (persiste aunque no tenga recuerdos)
        final prefs = await SharedPreferences.getInstance();
        List<String> customCategories =
            prefs.getStringList(_customCategoriesKey) ?? [];
        if (!customCategories.contains(categoryName)) {
          customCategories.add(categoryName);
          await prefs.setStringList(_customCategoriesKey, customCategories);
          print('Categoría guardada localmente: $categoryName');
        }
      }
    } catch (e) {
      print('Error creando categoría: $e');
      throw Exception('No se pudo crear la categoría: $e');
    }
  }

  /// Eliminar una categoría (mueve todos los recuerdos a "General")
  Future<void> deleteCategory(String categoryName) async {
    if (categoryName == 'General') {
      throw Exception('No se puede eliminar la categoría "General"');
    }

    try {
      // 1. Mover recuerdos reales a "General"
      final allMemories = await getMemories();
      int movedCount = 0;

      for (var memory in allMemories) {
        if (memory.category == categoryName) {
          final updatedMemory = memory.copyWith(category: 'General');
          await saveMemory(updatedMemory);
          movedCount++;
        }
      }

      // 2. SIEMPRE eliminar de SharedPreferences (aunque no tenga recuerdos)
      final prefs = await SharedPreferences.getInstance();
      List<String> customCategories =
          prefs.getStringList(_customCategoriesKey) ?? [];
      if (customCategories.contains(categoryName)) {
        customCategories.remove(categoryName);
        await prefs.setStringList(_customCategoriesKey, customCategories);
        print('✅ Categoría "$categoryName" eliminada de SharedPreferences');
      }

      print(
          '✅ Categoría eliminada: $categoryName ($movedCount recuerdos movidos a General)');
    } catch (e) {
      print('❌ Error eliminando categoría: $e');
      throw Exception('No se pudo eliminar la categoría: $e');
    }
  }

  /// Helper: Obtener un recuerdo por ID
  Future<Memory?> _getMemoryById(String id) async {
    try {
      final allMemories = await getMemories();
      try {
        return allMemories.firstWhere((m) => m.id == id);
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Obtener el número de recuerdos por categoría
  Future<int> getMemoryCountByCategory(String category) async {
    try {
      final allMemories = await getMemories();
      return allMemories.where((m) => m.category == category).length;
    } catch (e) {
      print('Error contando recuerdos para $category: $e');
      return 0;
    }
  }
}

// Extensión para copiar Memory
extension MemoryCopyWith on Memory {
  Memory copyWith({
    String? id,
    String? title,
    String? description,
    String? date,
    Map<String, double>? location,
    String? imageAsset,
    String? category,
    bool? isFavorite,
    List<String>? sharedWith,
    bool? hasPassword,
    String? passwordHash,
  }) {
    return Memory(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? this.location,
      imageAsset: imageAsset ?? this.imageAsset,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      sharedWith: sharedWith ?? this.sharedWith,
      hasPassword: hasPassword ?? this.hasPassword,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }
}