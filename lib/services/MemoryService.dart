import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/Memory.dart';
import 'package:uuid/uuid.dart';

class MemoryService {
  static const String _memoriesKey = 'nayeka memories';  
  static const String _storageBucket = 'nayeka memories';
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSupabaseAvailable = false;
  final Uuid _uuid = const Uuid();

  MemoryService() {
    _checkSupabaseConnection();
  }

  Future<void> _checkSupabaseConnection() async {
    try {
      final user = _supabase.auth.currentUser;
      _isSupabaseAvailable = user != null;
      print('Supabase disponible: $_isSupabaseAvailable');
    } catch (e) {
      print('Error checking Supabase connection: $e');
      _isSupabaseAvailable = false;
    }
  }

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

      // Subir la imagen
      await _supabase.storage.from(_storageBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Obtener URL pública con cache buster
      final String cacheBusterUrl = _getPublicUrlWithCacheBuster(path);

      print('Avatar subido exitosamente: $cacheBusterUrl');
      return cacheBusterUrl;
    } catch (e) {
      print('Error subiendo avatar: $e');
      return null;
    }
  }

  // obtenemos los recuerdos
  Future<List<Memory>> getMemories() async {
    try {
      if (_isSupabaseAvailable) {
        try {
          print('Intentando obtener de Supabase...');
          final supabaseMemories = await _getMemoriesFromSupabase();
          if (supabaseMemories.isNotEmpty) {
            print('${supabaseMemories.length} recuerdos cargados de Supabase');
            
            // Sincronizar locales con los de Supabase
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
      final Set<String> allIds = {...supabaseMap.keys, ...localMemories.map((m) => m.id)};
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
      final memoriesJson = mergedMemories.map((m) => jsonEncode(m.toMap())).toList();
      await prefs.setStringList(_memoriesKey, memoriesJson);
      
      print('Sincronización local completada: ${mergedMemories.length} recuerdos');
    } catch (e) {
      print('Error sincronizando con local: $e');
    }
  }

  // Obtener recuerdos de Supabase con manejo de tipos y errores robusto
  Future<List<Memory>> _getMemoriesFromSupabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Usuario no autenticado en Supabase');
        return [];
      }

      print('Buscando recuerdos para usuario: $userId');

      final response = await _supabase
          .from('nayeka memories') 
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      final List<Memory> memories = [];

      if (response is List) {
        print('${response.length} registros encontrados en Supabase');

        for (var item in response) {
          try {
            final memory = Memory.fromMap({
              'id': item['id']?.toString() ?? '',
              'title': item['title']?.toString() ?? 'Sin título',
              'description': item['description']?.toString() ?? '',
              'date': item['date']?.toString() ?? DateTime.now().toIso8601String(),
              'latitude': _parseDouble(item['latitude']),
              'longitude': _parseDouble(item['longitude']),
              'imageAsset': item['imageAsset']?.toString(),
              'category': item['category']?.toString() ?? 'General',
              'isFavorite': item['isFavorite'] ?? false,
            });
            memories.add(memory);
          } catch (e) {
            print('Error procesando item: $e');
          }
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
        print('  - Código: ${e.statusCode}');
        print('  - Mensaje: ${e.message}');

        if (e.statusCode == '404') {
          print('Error: El bucket "$_storageBucket" no existe.');
          print('Crea el bucket en Supabase Dashboard > Storage');
        }
      }
      return null;
    }
  }

  // Guardamos el recuerdo con imagen
  Future<String> saveMemoryWithImage({
    required Memory memory,
    required Uint8List imageBytes,
  }) async {
    print('Guardando recuerdo con imagen...');

    try {
      final memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      print('ID generado para memoria: $memoryId');

      String? imageUrl;
      if (_isSupabaseAvailable) {
        print('Intentando subir imagen a Supabase...');
        imageUrl = await uploadImage(imageBytes);
        if (imageUrl != null) {
          print('Imagen subida: $imageUrl');
        } else {
          print('No se pudo subir la imagen');
        }
      } else {
        print('Sin conexión a Supabase, omitiendo subida de imagen');
      }

      final finalMemory = memory.copyWith(
        id: memoryId,
        imageAsset: imageUrl,
      );

      await _saveMemoryToLocal(finalMemory);
      print('Memoria guardada localmente: $memoryId');

      if (_isSupabaseAvailable) {
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

      if (_isSupabaseAvailable) {
        videoUrl = await uploadVideo(videoBytes);
      }

      final finalMemory = memory.copyWith(
        id: memoryId,
        imageAsset: videoUrl,
      );

      await _saveMemoryToLocal(finalMemory);
      print('Memoria (video) guardada localmente: $memoryId');

      if (_isSupabaseAvailable) {
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
        'updated_at': DateTime.now().toIso8601String(),
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
      final finalMemory = memory.copyWith(id: memoryId);

      await _saveMemoryToLocal(finalMemory);

      if (_isSupabaseAvailable) {
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
        final memoriesJson = memories.map((m) => jsonEncode(m.toMap())).toList();
        await prefs.setStringList(_memoriesKey, memoriesJson);
        print('Estado de favorito actualizado localmente: $isFavorite');
      }

      // 2. Actualizar en Supabase
      if (_isSupabaseAvailable) {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase
              .from('nayeka memories') 
              .update({'isFavorite': isFavorite})
              .eq('id', memoryId)
              .eq('user_id', userId);
          print('Favorito actualizado en Supabase: $memoryId -> $isFavorite');
        }
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
            final contents = await _supabase.storage.from(_storageBucket).list(path: folder);
            print('Carpeta $folder encontrada: ${contents.length} archivos');
          } catch (e) {
            print('La carpeta "$folder" se creará automáticamente al subir archivos');
          }
        }
      } catch (e) {
        if (e is StorageException && e.message.contains('not found')) {
          print('El bucket "$_storageBucket" no existe');
          print('Ve a Supabase Dashboard > Storage y:');
          print('   1. Click en "Create a new bucket"');
          print('   2. Nombre: "$_storageBucket" (con espacio)');
          print('   3. Marca "Make it public"');
          print('   4. Click "Create bucket"');
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
      print('\n verificamos la table "nayeka memories"...');
      try {
        final response = await _supabase
            .from('nayeka memories') 
            .select('id')
            .limit(1);

        if (response != null) {
          print('Tabla accesible');
        }
      } catch (e) {
        print('Error accediendo a tabla: $e');
        print('   Crea la tabla en Supabase Dashboard > SQL Editor:');
        print('''
          CREATE TABLE "nayeka memories" (  
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            user_id UUID NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            date TEXT NOT NULL,
            latitude DOUBLE PRECISION,
            longitude DOUBLE PRECISION,
            imageAsset TEXT,
            category TEXT,
            isFavorite BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );
        ''');
      }

      // 2. Verificar Storage
      print('\n verificando storage...');
      await verifyStorageBucket();

      print('\n' + '=' * 50);
      print('prueba completa');
    } catch (e) {
      print('Error en testSupabaseConnection: $e');
    }
  }

  // Eliminar recuerdo
  Future<void> deleteMemory(String id) async {
    try {
      print('Eliminando recuerdo: $id');
      await _deleteMemoryFromLocal(id);

      if (_isSupabaseAvailable) {
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
      final memoriesJson = updatedMemories.map((m) => jsonEncode(m.toMap())).toList();

      await prefs.setStringList(_memoriesKey, memoriesJson);
      print('Recuerdo eliminado localmente: $id');
      print('Recuerdos restantes: ${updatedMemories.length}');
    } catch (e) {
      print('Error eliminando localmente: $e');
    }
  }

  Future<void> _deleteMemoryFromSupabase(String id) async {
    try {
      await _supabase
          .from('nayeka memories') 
          .delete()
          .eq('id', id);

      print('Recuerdo eliminado de Supabase: $id');
    } catch (e) {
      print('Error eliminando de Supabase: $e');
    }
  }

  // Limpiar todos los recuerdos
  Future<void> clearAllMemories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_memoriesKey);

      if (_isSupabaseAvailable) {
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
        await _supabase
            .from('nayeka memories') 
            .delete()
            .eq('user_id', userId);

        print('Todos los recuerdos eliminados de Supabase');
      }
    } catch (e) {
      print('Error limpiando Supabase: $e');
    }
  }

  // Verificamos la conexión a Supabase
  bool isSupabaseConnected() {
    return _isSupabaseAvailable;
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
    );
  }
}