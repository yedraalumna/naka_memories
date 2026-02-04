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
  final Uuid _uuid = Uuid();

  MemoryService() {
    _checkSupabaseConnection();
  }

  Future<void> _checkSupabaseConnection() async {
    try {
      final user = _supabase.auth.currentUser;
      _isSupabaseAvailable = user != null;
      print('🔌 Supabase disponible: $_isSupabaseAvailable');
    } catch (e) {
      print('Error checking Supabase connection: $e');
      _isSupabaseAvailable = false;
    }
  }

  String _generateId() {
    return _uuid.v4();
  }

  // 1. OBTENER RECUERDOS
  Future<List<Memory>> getMemories() async {
    try {
      if (_isSupabaseAvailable) {
        try {
          print('📡 Intentando obtener de Supabase...');
          final supabaseMemories = await _getMemoriesFromSupabase();
          if (supabaseMemories.isNotEmpty) {
            print('✅ ${supabaseMemories.length} recuerdos cargados de Supabase');
            return supabaseMemories;
          }
        } catch (e) {
          print('⚠️ Error obteniendo de Supabase: $e');
        }
      }
      print('📱 Cargando desde almacenamiento local...');
      return await _getMemoriesFromLocal();
    } catch (e) {
      print('❌ Error general obteniendo recuerdos: $e');
      return await _getMemoriesFromLocal();
    }
  }

  // OBTENER DE SUPABASE
  Future<List<Memory>> _getMemoriesFromSupabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ Usuario no autenticado en Supabase');
        return [];
      }

      print('🔍 Buscando recuerdos para usuario: $userId');
      
      final response = await _supabase
          .from('nayeka memories')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      final List<Memory> memories = [];
      
      if (response is List) {
        print('📊 ${response.length} registros encontrados en Supabase');
        
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
            });
            memories.add(memory);
          } catch (e) {
            print('⚠️ Error procesando item: $e');
          }
        }
      }
      
      return memories;
    } catch (e) {
      print('❌ Error en _getMemoriesFromSupabase: $e');
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

  // OBTENER DE LOCAL
  Future<List<Memory>> _getMemoriesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoriesJson = prefs.getStringList(_memoriesKey) ?? [];
      print('📁 ${memoriesJson.length} recuerdos en almacenamiento local');

      final List<Memory> memories = [];
      
      for (final json in memoriesJson) {
        try {
          final map = jsonDecode(json);
          memories.add(Memory.fromMap(map));
        } catch (e) {
          print('⚠️ Error parseando memoria local: $e');
        }
      }
      
      return memories;
    } catch (e) {
      print('❌ Error en _getMemoriesFromLocal: $e');
      return [];
    }
  }

  // 2. SUBIR IMAGEN
  Future<String?> uploadImage(Uint8List imageBytes) async {
    try {
      if (imageBytes.isEmpty) {
        print('⚠️ Bytes de imagen vacíos');
        return null;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ Usuario no autenticado para subir imagen');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = _uuid.v4().substring(0, 8);
      final fileName = '${userId}_${timestamp}_$random.jpg';
      
      print('📤 Subiendo imagen: $fileName (${imageBytes.length} bytes)');
      print('🗂️  Bucket destino: $_storageBucket');

      try {
        await _supabase.storage
            .from(_storageBucket)
            .upload(
              fileName, 
              imageBytes,
              fileOptions: FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: false,
              ),
            );

        print('✅ Imagen subida exitosamente');

        final publicUrl = _supabase.storage
            .from(_storageBucket)
            .getPublicUrl(fileName);

        print('✅ URL pública obtenida: $publicUrl');
        return publicUrl;
        
      } catch (uploadError) {
        print('⚠️ Error en upload: $uploadError');
        
        try {
          print('🔄 Intentando método alternativo...');
          
          final response = await _supabase.storage
              .from(_storageBucket)
              .uploadBinary(
                fileName,
                imageBytes,
                fileOptions: FileOptions(
                  contentType: 'image/jpeg',
                  cacheControl: '3600',
                ),
              );
          
          final publicUrl = _supabase.storage
              .from(_storageBucket)
              .getPublicUrl(fileName);
          
          print('✅ Imagen subida (método alternativo): $publicUrl');
          return publicUrl;
        } catch (e) {
          print('❌ Ambos métodos fallaron: $e');
          return null;
        }
      }
      
    } catch (e) {
      print('❌ Error general subiendo imagen: $e');
      
      if (e is StorageException) {
        print('📋 Storage error details:');
        print('  - Status code: ${e.statusCode}');
        print('  - Message: ${e.message}');
        print('  - Error: ${e.error}');
        
        if (e.statusCode == 404) {
          print('🔍 El bucket "$_storageBucket" no existe en Storage');
        }
      }
      
      return null;
    }
  }

  // 3. GUARDAR RECUERDO CON IMAGEN
  Future<String> saveMemoryWithImage({
    required Memory memory,
    required Uint8List imageBytes,
  }) async {
    print('💾 Guardando recuerdo con imagen...');
    
    try {
      final memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      print('🆔 ID generado para memoria: $memoryId');
      
      String? imageUrl;
      if (_isSupabaseAvailable) {
        print('🌐 Intentando subir imagen a Supabase...');
        imageUrl = await uploadImage(imageBytes);
        if (imageUrl != null) {
          print('✅ Imagen subida: $imageUrl');
        } else {
          print('⚠️ No se pudo subir la imagen');
        }
      } else {
        print('📴 Sin conexión a Supabase, omitiendo subida de imagen');
      }
      
      final finalMemory = memory.copyWith(
        id: memoryId,
        imageAsset: imageUrl,
      );
      
      await _saveMemoryToLocal(finalMemory);
      print('📁 Memoria guardada localmente: $memoryId');
      
      if (_isSupabaseAvailable) {
        try {
          await _saveMemoryToSupabase(finalMemory);
          print('☁️ Memoria guardada en Supabase: $memoryId');
        } catch (e) {
          print('⚠️ Error guardando en Supabase, pero guardado localmente: $e');
        }
      }
      
      return memoryId;
      
    } catch (e) {
      print('❌ Error en saveMemoryWithImage: $e');
      rethrow;
    }
  }

  // 4. GUARDAR RECUERDO EN SUPABASE
  Future<void> _saveMemoryToSupabase(Memory memory) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      if (memory.id.isEmpty) {
        throw Exception('ID de memoria no puede estar vacío');
      }

      print('☁️ Guardando en Supabase: ${memory.id}');

      final memoryData = {
        'id': memory.id,
        'user_id': userId,
        'title': memory.title,
        'description': memory.description ?? '',
        'date': memory.date,
        'latitude': memory.location['latitude'] ?? 0.0,
        'longitude': memory.location['longitude'] ?? 0.0,
        'imageAsset': memory.imageAsset,
        'created_at': DateTime.now().toIso8601String(),
      };

      print('📋 Datos a guardar: $memoryData');

      final response = await _supabase
          .from('nayeka memories')
          .upsert(memoryData, onConflict: 'id')
          .select();
      
      print('✅ Recuerdo guardado en Supabase: ${memory.id}');
      
    } catch (e) {
      print('❌ Error guardando en Supabase: $e');
      throw Exception('Error al guardar en la nube: $e');
    }
  }

  // 5. GUARDAR LOCALMENTE
  Future<void> _saveMemoryToLocal(Memory memory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Memory> memories = await _getMemoriesFromLocal();

      final String memoryId = memory.id.isNotEmpty 
          ? memory.id
          : _generateId();

      final finalMemory = memory.copyWith(id: memoryId);

      final existingIndex = memories.indexWhere((m) => m.id == memoryId);

      if (existingIndex >= 0) {
        memories[existingIndex] = finalMemory;
        print('📝 Actualizando memoria local: $memoryId');
      } else {
        memories.add(finalMemory);
        print('➕ Agregando nueva memoria local: $memoryId');
      }

      final memoriesJson = memories.map((m) => jsonEncode(m.toMap())).toList();
      await prefs.setStringList(_memoriesKey, memoriesJson);
      
      print('📁 Total de recuerdos locales: ${memories.length}');
      
    } catch (e) {
      print('❌ Error guardando localmente: $e');
      throw Exception('Error al guardar localmente: $e');
    }
  }

  // 6. GUARDAR RECUERDO SIN IMAGEN
  Future<void> saveMemory(Memory memory) async {
    try {
      print('💾 Guardando recuerdo: ${memory.id}');
      
      final memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      final finalMemory = memory.copyWith(id: memoryId);
      
      await _saveMemoryToLocal(finalMemory);
      
      if (_isSupabaseAvailable) {
        await _saveMemoryToSupabase(finalMemory);
      }
      
      print('✅ Recuerdo guardado exitosamente: $memoryId');
      
    } catch (e) {
      print('❌ Error guardando recuerdo: $e');
      rethrow;
    }
  }

  // 7. MÉTODO PARA VERIFICAR Y CREAR BUCKET
  Future<void> verifyStorageBucket() async {
    try {
      print('🔍 Verificando bucket de Storage...');
      
      try {
        final files = await _supabase.storage
            .from(_storageBucket)
            .list();
        
        print('✅ Bucket "$_storageBucket" accesible');
        print('📄 Archivos en bucket: ${files.length}');
      } catch (e) {
        if (e is StorageException && e.message.contains('not found')) {
          print('❌ El bucket "$_storageBucket" no existe');
          print('💡 Ve a Supabase Dashboard > Storage y:');
          print('   1. Click en "Create a new bucket"');
          print('   2. Nombre: "nayeka memories" (con espacio)');
          print('   3. Marca "Make it public"');
          print('   4. Click "Create bucket"');
        } else {
          print('⚠️ Error accediendo al bucket: $e');
        }
      }
      
    } catch (e) {
      print('❌ Error verificando bucket: $e');
    }
  }

  // 8. MÉTODO COMPLETO DE PRUEBA - SIN ERRORES
  Future<void> testSupabaseConnection() async {
    try {
      print('🧪 PRUEBA COMPLETA DE SUPABASE 🧪');
      print('=' * 50);
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ Usuario no autenticado');
        return;
      }
      print('✅ Usuario autenticado: ${user.id}');
      
      // 1. Verificar tabla
      print('\n1️⃣ VERIFICANDO TABLA "nayeka memories"...');
      try {
        final response = await _supabase
            .from('nayeka memories')
            .select('id')
            .limit(1);
        
        if (response != null) {
          print('✅ Tabla accesible - ${response.length} registros encontrados');
        }
      } catch (e) {
        print('❌ Error accediendo a tabla: $e');
      }
      
      // 2. Verificar Storage
      print('\n2️⃣ VERIFICANDO STORAGE...');
      await verifyStorageBucket();
      
      // 3. Prueba de escritura
      print('\n3️⃣ PRUEBA DE ESCRITURA...');
      final testId = _generateId();
      final testData = {
        'id': testId,
        'user_id': user.id,
        'title': 'Prueba de conexión',
        'description': 'Este es un registro de prueba',
        'date': DateTime.now().toIso8601String(),
        'latitude': 0.0,
        'longitude': 0.0,
        'imageAsset': null,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      try {
        await _supabase
            .from('nayeka memories')
            .insert(testData);
        print('✅ Escritura exitosa en tabla');
        
        final response = await _supabase
            .from('nayeka memories')
            .select()
            .eq('id', testId);
        
        if (response != null && response.isNotEmpty) {
          print('✅ Lectura exitosa de tabla');
        }
        
        await _supabase
            .from('nayeka memories')
            .delete()
            .eq('id', testId);
        print('✅ Datos de prueba eliminados');
        
      } catch (e) {
        print('❌ Error en prueba de escritura: $e');
      }
      
      print('\n' + '=' * 50);
      print('🧪 PRUEBA COMPLETADA 🧪');
      
    } catch (e) {
      print('❌ Error en testSupabaseConnection: $e');
    }
  }

  // Resto de métodos (sin cambios)
  Future<void> deleteMemory(String id) async {
    try {
      print('🗑️ Eliminando recuerdo: $id');
      await _deleteMemoryFromLocal(id);
      
      if (_isSupabaseAvailable) {
        await _deleteMemoryFromSupabase(id);
      }
    } catch (e) {
      print('❌ Error eliminando recuerdo: $e');
    }
  }

  Future<void> _deleteMemoryFromLocal(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memories = await _getMemoriesFromLocal();
      
      final updatedMemories = memories.where((m) => m.id != id).toList();
      final memoriesJson = updatedMemories.map((m) => jsonEncode(m.toMap())).toList();
      
      await prefs.setStringList(_memoriesKey, memoriesJson);
      print('🗑️ Recuerdo eliminado localmente: $id');
      print('📁 Recuerdos restantes: ${updatedMemories.length}');
    } catch (e) {
      print('❌ Error eliminando localmente: $e');
    }
  }

  Future<void> _deleteMemoryFromSupabase(String id) async {
    try {
      await _supabase
          .from('nayeka memories')
          .delete()
          .eq('id', id);
      
      print('☁️ Recuerdo eliminado de Supabase: $id');
    } catch (e) {
      print('❌ Error eliminando de Supabase: $e');
    }
  }

  Future<void> clearAllMemories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_memoriesKey);
      
      if (_isSupabaseAvailable) {
        await _clearAllMemoriesFromSupabase();
      }
      
      print('🧹 Todos los recuerdos eliminados');
    } catch (e) {
      print('❌ Error limpiando recuerdos: $e');
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
        
        print('☁️ Todos los recuerdos eliminados de Supabase');
      }
    } catch (e) {
      print('❌ Error limpiando Supabase: $e');
    }
  }

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
  }) {
    return Memory(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? this.location,
      imageAsset: imageAsset ?? this.imageAsset,
    );
  }
}