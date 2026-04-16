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

  String getPublicUrl(String path) {
    try {
      return _supabase.storage.from(_storageBucket).getPublicUrl(path);
    } catch (e) {
      print('Error obteniendo URL pública: $e');
      return '';
    }
  }

  String _getPublicUrlWithCacheBuster(String path) {
    try {
      final publicUrl = getPublicUrl(path);
      return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Error obteniendo URL con cache buster: $e');
      return '';
    }
  }

  Future<String?> uploadAvatar(Uint8List bytes, String userId) async {
    try {
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

      return _getPublicUrlWithCacheBuster(path);
    } catch (e) {
      print('Error subiendo avatar: $e');
      return null;
    }
  }

  Future<List<Memory>> getMemories() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        try {
          final supabaseMemories = await _getMemoriesFromSupabase();
          if (supabaseMemories.isNotEmpty) {
            await _syncLocalWithSupabase(supabaseMemories);
            return supabaseMemories;
          }
        } catch (e) {
          print('Error obteniendo de Supabase: $e');
        }
      }

      return await _getMemoriesFromLocal();
    } catch (e) {
      print('Error general obteniendo recuerdos: $e');
      return [];
    }
  }

  Future<void> _syncLocalWithSupabase(List<Memory> supabaseMemories) async {
    try {
      final localMemories = await _getMemoriesFromLocal();
      final prefs = await SharedPreferences.getInstance();

      final Map<String, Memory> supabaseMap = {};
      for (var m in supabaseMemories) {
        supabaseMap[m.id] = m;
      }

      final Set<String> allIds = {};
      for (var id in supabaseMap.keys) {
        allIds.add(id);
      }
      for (var m in localMemories) {
        allIds.add(m.id);
      }

      final List<Memory> mergedMemories = [];

      for (final id in allIds) {
        if (supabaseMap.containsKey(id)) {
          mergedMemories.add(supabaseMap[id]!);
        } else {
          final localMemory = localMemories.firstWhere((m) => m.id == id);
          mergedMemories.add(localMemory);
        }
      }

      final List<String> memoriesJson = [];
      for (var m in mergedMemories) {
        memoriesJson.add(jsonEncode(m.toMap()));
      }
      await prefs.setStringList(_memoriesKey, memoriesJson);
    } catch (e) {
      print('Error sincronizando con local: $e');
    }
  }

  Future<List<Memory>> _getMemoriesFromSupabase() async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      final userEmail = user?.email;

      if (userId == null) {
        return [];
      }

      final response = await _supabase
          .from('nayeka memories')
          .select()
          .or('user_id.eq.$userId,shared_with.cs.{$userEmail}')
          .order('date', ascending: false);

      final List<Memory> memories = [];

      for (var item in response) {
        try {
          memories.add(Memory.fromMap(item));
        } catch (e) {
          // Error silencioso
        }
      }

      return memories;
    } catch (e) {
      print('Error en _getMemoriesFromSupabase: $e');
      return [];
    }
  }

  Future<void> shareCategoryWithRole(
      String category, String emailToShare, String selectedRole) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || emailToShare.isEmpty) return;

      final response = await _supabase
          .from('nayeka memories')
          .select()
          .eq('user_id', user.id)
          .eq('category', category);

      for (var item in response) {
        List<String> currentShared = [];
        if (item['shared_with'] != null) {
          for (var e in item['shared_with']) {
            currentShared.add(e.toString());
          }
        }

        Map<String, dynamic> currentRoles = {};
        if (item['shared_roles'] != null) {
          currentRoles = Map<String, dynamic>.from(item['shared_roles']);
        }

        Map<String, dynamic> currentPending = {};
        if (item['pending_roles'] != null) {
          currentPending = Map<String, dynamic>.from(item['pending_roles']);
        }

        if (selectedRole == 'quitar') {
          currentShared.remove(emailToShare);
          currentRoles.remove(emailToShare);
          currentPending.remove(emailToShare);
        } else {
          currentShared.remove(emailToShare);
          currentRoles.remove(emailToShare);
          currentPending[emailToShare] = selectedRole;
        }

        await _supabase.from('nayeka memories').update({
          'shared_with': currentShared,
          'shared_roles': currentRoles,
          'pending_roles': currentPending,
        }).eq('id', item['id']);
      }

      await getMemories();
    } catch (e) {
      print('Error en shareCategoryWithRole: $e');
      throw e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<List<Memory>> _getMemoriesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoriesJson = prefs.getStringList(_memoriesKey) ?? [];

      final List<Memory> memories = [];

      for (final json in memoriesJson) {
        try {
          final map = jsonDecode(json);
          memories.add(Memory.fromMap(map));
        } catch (e) {
          // Error silencioso
        }
      }

      return memories;
    } catch (e) {
      print('Error en _getMemoriesFromLocal: $e');
      return [];
    }
  }

  Future<String?> uploadImage(Uint8List imageBytes) async {
    try {
      if (imageBytes.isEmpty) return null;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = _uuid.v4().substring(0, 8);
      final fileName = '${userId}_${timestamp}_$random.jpg';
      final path = 'memories/$fileName';

      await _supabase.storage.from(_storageBucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
              upsert: false,
            ),
          );

      return _getPublicUrlWithCacheBuster(path);
    } catch (e) {
      print('Error subiendo imagen: $e');
      return null;
    }
  }

  Future<Memory> _inheritSharedUsers(Memory memory) async {
    if (memory.category == 'Sin categoría' || memory.category.isEmpty) {
      return memory;
    }
    try {
      final localMemories = await _getMemoriesFromLocal();
      final List<Memory> categoryMemories = [];
      for (var m in localMemories) {
        if (m.category == memory.category) {
          categoryMemories.add(m);
        }
      }

      Set<String> allSharedEmails = {};
      for (var email in memory.sharedWith) {
        allSharedEmails.add(email);
      }

      Map<String, dynamic> allRoles = {};
      if (memory.sharedRoles != null) {
        for (var entry in memory.sharedRoles!.entries) {
          allRoles[entry.key] = entry.value;
        }
      }

      for (var m in categoryMemories) {
        for (var email in m.sharedWith) {
          allSharedEmails.add(email);
        }
        if (m.sharedRoles != null) {
          for (var entry in m.sharedRoles!.entries) {
            allRoles[entry.key] = entry.value;
          }
        }
      }

      final List<String> sharedList = [];
      for (var email in allSharedEmails) {
        sharedList.add(email);
      }

      return memory.copyWith(
        sharedWith: sharedList,
        sharedRoles: allRoles,
      );
    } catch (e) {
      print('Error heredando usuarios y roles: $e');
      return memory;
    }
  }

  Future<String> saveMemoryWithImage({
    required Memory memory,
    required Uint8List imageBytes,
  }) async {
    try {
      final memoryId = memory.id.isNotEmpty ? memory.id : _generateId();

      String? imageUrl;
      final user = _supabase.auth.currentUser;

      if (user != null) {
        imageUrl = await uploadImage(imageBytes);
      }

      Memory finalMemory = memory.copyWith(
        id: memoryId,
        imageAsset: imageUrl,
      );

      finalMemory = await _inheritSharedUsers(finalMemory);
      await _saveMemoryToLocal(finalMemory);

      if (user != null) {
        try {
          await _saveMemoryToSupabase(finalMemory);
        } catch (e) {
          // Error guardando en Supabase, pero local está guardado
        }
      }
      return memoryId;
    } catch (e) {
      print('Error en saveMemoryWithImage: $e');
      rethrow;
    }
  }

  Future<String?> uploadVideo(Uint8List videoBytes) async {
    try {
      if (videoBytes.isEmpty) return null;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = _uuid.v4().substring(0, 8);
      final fileName = '${userId}_${timestamp}_$random.mp4';
      final path = 'videos/$fileName';

      await _supabase.storage.from(_storageBucket).uploadBinary(
            path,
            videoBytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              cacheControl: '3600',
              upsert: false,
            ),
          );

      return _getPublicUrlWithCacheBuster(path);
    } catch (e) {
      print('Error subiendo video: $e');
      return null;
    }
  }

  Future<Memory> saveMemoryWithVideo({
    required Memory memory,
    required Uint8List videoBytes,
  }) async {
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

      finalMemory = await _inheritSharedUsers(finalMemory);
      await _saveMemoryToLocal(finalMemory);

      if (user != null) {
        try {
          await _saveMemoryToSupabase(finalMemory);
        } catch (e) {
          // Error guardando en Supabase, pero local está guardado
        }
      }

      return finalMemory;
    } catch (e) {
      print('Error en saveMemoryWithVideo: $e');
      rethrow;
    }
  }

  Future<void> _saveMemoryToSupabase(Memory memory) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Usuario no autenticado');

      final String finalUserId = memory.creatorId ?? currentUser.id;

      final String? finalUserEmail = (memory.creatorId != null)
          ? memory.creatorEmail
          : (memory.creatorEmail ?? currentUser.email);

      final memoryData = {
        'id': memory.id,
        'user_id': finalUserId,
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
        'shared_roles': memory.sharedRoles,
        'pending_roles': memory.pendingRoles,
        'creator_email': finalUserEmail,
      };

      await _supabase
          .from('nayeka memories')
          .upsert(memoryData, onConflict: 'id');
    } catch (e) {
      print('Error guardando en Supabase: $e');
      throw Exception('Error al guardar en la nube: $e');
    }
  }

  Future<void> _saveMemoryToLocal(Memory memory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Memory> memories = await _getMemoriesFromLocal();

      final String memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      final finalMemory = memory.copyWith(id: memoryId);

      final existingIndex = memories.indexWhere((m) => m.id == memoryId);

      if (existingIndex >= 0) {
        memories[existingIndex] = finalMemory;
      } else {
        memories.add(finalMemory);
      }

      final List<String> memoriesJson = [];
      for (var m in memories) {
        memoriesJson.add(jsonEncode(m.toMap()));
      }
      await prefs.setStringList(_memoriesKey, memoriesJson);
    } catch (e) {
      print('Error guardando localmente: $e');
      throw Exception('Error al guardar localmente: $e');
    }
  }

  Future<void> saveMemory(Memory memory) async {
    try {
      final memoryId = memory.id.isNotEmpty ? memory.id : _generateId();
      Memory finalMemory = memory.copyWith(id: memoryId);

      finalMemory = await _inheritSharedUsers(finalMemory);
      await _saveMemoryToLocal(finalMemory);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _saveMemoryToSupabase(finalMemory);
      }
    } catch (e) {
      print('Error guardando recuerdo: $e');
      rethrow;
    }
  }

  Future<void> updateFavoriteStatus(String memoryId, bool isFavorite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memories = await _getMemoriesFromLocal();

      final index = memories.indexWhere((m) => m.id == memoryId);
      if (index >= 0) {
        memories[index] = memories[index].copyWith(isFavorite: isFavorite);
        final List<String> memoriesJson = [];
        for (var m in memories) {
          memoriesJson.add(jsonEncode(m.toMap()));
        }
        await prefs.setStringList(_memoriesKey, memoriesJson);
      }

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('nayeka memories')
            .update({'isFavorite': isFavorite})
            .eq('id', memoryId)
            .eq('user_id', user.id);
      }
    } catch (e) {
      print('Error actualizando estado de favorito: $e');
    }
  }

  Future<Map<String, String?>> getCategoryPasswordsFromMemories() async {
    final Map<String, String?> result = {};

    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        final userEmail = user.email;
        final response = await _supabase
            .from('nayeka memories')
            .select('category, has_password, password_hash')
            .or('user_id.eq.${user.id},shared_with.cs.{$userEmail}');

        for (final row in response) {
          final category = row['category']?.toString();
          final hasPassword = row['has_password'] == true;
          final hash = row['password_hash']?.toString();

          if (category == null || category.trim().isEmpty) continue;
          if (hasPassword != true) continue;
          if (hash == null || hash.isEmpty) continue;

          if (!result.containsKey(category)) {
            result[category] = hash;
          }
        }
      }
    } catch (e) {
      print('Error cargando contraseñas desde Supabase: $e');
    }

    try {
      final localMemories = await _getMemoriesFromLocal();
      for (final memory in localMemories) {
        if (memory.hasPassword != true) continue;
        if (memory.passwordHash == null) continue;
        if (memory.passwordHash!.isEmpty) continue;
        if (!result.containsKey(memory.category)) {
          result[memory.category] = memory.passwordHash;
        }
      }
    } catch (e) {
      print('Error cargando contraseñas desde local: $e');
    }

    return result;
  }

  Future<void> applyCategoryPasswordToMemories(
      String categoryName, String? passwordHash) async {
    try {
      final hasPassword = (passwordHash != null && passwordHash.isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      final memories = await _getMemoriesFromLocal();

      final List<Memory> updated = [];
      for (var m in memories) {
        if (m.category != categoryName) {
          updated.add(m);
        } else {
          if (hasPassword) {
            updated.add(m.copyWith(
              hasPassword: true,
              passwordHash: passwordHash,
            ));
          } else {
            updated.add(m.copyWith(
              hasPassword: false,
              passwordHash: null,
            ));
          }
        }
      }

      final List<String> memoriesJson = [];
      for (var m in updated) {
        memoriesJson.add(jsonEncode(m.toMap()));
      }
      await prefs.setStringList(_memoriesKey, memoriesJson);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('nayeka memories')
            .update({
              'has_password': hasPassword,
              'password_hash': hasPassword ? passwordHash : null,
            })
            .eq('user_id', user.id)
            .eq('category', categoryName);
      }
    } catch (e) {
      print('Error aplicando PIN de categoría: $e');
    }
  }

  Future<void> deleteMemory(String id) async {
    try {
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

      final List<Memory> updatedMemories = [];
      for (var m in memories) {
        if (m.id != id) {
          updatedMemories.add(m);
        }
      }

      final List<String> memoriesJson = [];
      for (var m in updatedMemories) {
        memoriesJson.add(jsonEncode(m.toMap()));
      }
      await prefs.setStringList(_memoriesKey, memoriesJson);
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
      }
    } catch (e) {
      print('Error eliminando de Supabase: $e');
    }
  }

  Future<void> clearAllMemories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_memoriesKey);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _clearAllMemoriesFromSupabase();
      }
    } catch (e) {
      print('Error limpiando recuerdos: $e');
    }
  }

  Future<void> _clearAllMemoriesFromSupabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('nayeka memories').delete().eq('user_id', userId);
      }
    } catch (e) {
      print('Error limpiando Supabase: $e');
    }
  }

  Future<List<String>> getAllCategories() async {
    try {
      final user = _supabase.auth.currentUser;
      Set<String> uniqueCategories = {'General'};

      if (user != null) {
        final userEmail = user.email;
        final response = await _supabase
            .from('nayeka memories')
            .select('category')
            .or('user_id.eq.${user.id},shared_with.cs.{$userEmail}');

        for (var item in response) {
          final cat = item['category'] as String?;
          if (cat != null && cat.trim().isNotEmpty) {
            uniqueCategories.add(cat);
          }
        }
      } else {
        final localMemories = await _getMemoriesFromLocal();
        for (var m in localMemories) {
          uniqueCategories.add(m.category);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
      for (var cat in customCategories) {
        uniqueCategories.add(cat);
      }

      List<String> result = [];
      for (var cat in uniqueCategories) {
        result.add(cat);
      }
      result.sort();
      return result;
    } catch (e) {
      print('Error en getAllCategories: $e');
      return ['General'];
    }
  }

  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == 'General' || oldName == newName) return;

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('nayeka memories')
            .update({'category': newName})
            .eq('category', oldName)
            .eq('user_id', user.id);
      }

      final prefs = await SharedPreferences.getInstance();
      final memories = await _getMemoriesFromLocal();

      final List<Memory> updated = [];
      for (var m in memories) {
        if (m.category == oldName) {
          updated.add(m.copyWith(category: newName));
        } else {
          updated.add(m);
        }
      }

      final List<String> memoriesJson = [];
      for (var m in updated) {
        memoriesJson.add(jsonEncode(m.toMap()));
      }
      await prefs.setStringList(_memoriesKey, memoriesJson);

      final customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
      final List<String> updatedCategories = [];
      for (var cat in customCategories) {
        if (cat == oldName) {
          updatedCategories.add(newName);
        } else {
          updatedCategories.add(cat);
        }
      }
      await prefs.setStringList(_customCategoriesKey, updatedCategories);
    } catch (e) {
      print('Error renombrando categoría: $e');
      throw Exception('No se pudo renombrar la categoría: $e');
    }
  }

  Future<void> restoreDefaultCategories() async {
    final List<String> defaultCategories = [
      'Viajes', 'Amigos', 'Familia', 'Comida', 'Estudio'
    ];
    
    try {
      for (var category in defaultCategories) {
        final prefs = await SharedPreferences.getInstance();
        List<String> customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
        
        bool existe = false;
        for (var cat in customCategories) {
          if (cat == category) {
            existe = true;
            break;
          }
        }
        
        if (!existe) {
          customCategories.add(category);
          await prefs.setStringList(_customCategoriesKey, customCategories);
        }
      }
    } catch (e) {
      print('Error al restaurar categorías: $e');
      rethrow;
    }
  }

  Future<void> createCategory(String categoryName, {String? memoryId}) async {
    if (categoryName.isEmpty) return;

    try {
      if (memoryId != null) {
        final memory = await _getMemoryById(memoryId);
        if (memory != null) {
          final updatedMemory = memory.copyWith(category: categoryName);
          await saveMemory(updatedMemory);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        List<String> customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
        
        bool existe = false;
        for (var cat in customCategories) {
          if (cat == categoryName) {
            existe = true;
            break;
          }
        }
        
        if (!existe) {
          customCategories.add(categoryName);
          await prefs.setStringList(_customCategoriesKey, customCategories);
        }
      }
    } catch (e) {
      print('Error creando categoría: $e');
      throw Exception('No se pudo crear la categoría: $e');
    }
  }

  Future<void> deleteCategory(String categoryName) async {
    if (categoryName == 'General') {
      throw Exception('No se puede eliminar la categoría "General"');
    }

    try {
      final allMemories = await getMemories();
      int movedCount = 0;

      for (var memory in allMemories) {
        if (memory.category == categoryName) {
          final updatedMemory = memory.copyWith(category: 'General');
          await saveMemory(updatedMemory);
          movedCount++;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      List<String> customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
      
      final List<String> updatedCategories = [];
      for (var cat in customCategories) {
        if (cat != categoryName) {
          updatedCategories.add(cat);
        }
      }
      await prefs.setStringList(_customCategoriesKey, updatedCategories);
    } catch (e) {
      print('Error eliminando categoría: $e');
      throw Exception('No se pudo eliminar la categoría: $e');
    }
  }

  Future<Memory?> _getMemoryById(String id) async {
    try {
      final allMemories = await getMemories();
      for (var m in allMemories) {
        if (m.id == id) {
          return m;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int> getMemoryCountByCategory(String category) async {
    try {
      final allMemories = await getMemories();
      int count = 0;
      for (var m in allMemories) {
        if (m.category == category) {
          count++;
        }
      }
      return count;
    } catch (e) {
      print('Error contando recuerdos para $category: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingInvitations(String userEmail) async {
    try {
      final response = await _supabase.from('nayeka memories').select();

      List<Map<String, dynamic>> invitations = [];
      Set<String> seenCategories = {};

      for (var item in response) {
        if (item['pending_roles'] != null && item['pending_roles'][userEmail] != null) {
          String category = item['category'];
          String ownerEmail = item['creator_email'] ?? 'Un usuario';
          String role = item['pending_roles'][userEmail];
          String ownerId = item['user_id'];
          String uniqueKey = '${ownerId}_$category';

          bool yaVista = false;
          for (var seen in seenCategories) {
            if (seen == uniqueKey) {
              yaVista = true;
              break;
            }
          }

          if (!yaVista) {
            seenCategories.add(uniqueKey);
            invitations.add({
              'category': category,
              'owner_id': ownerId,
              'owner_email': ownerEmail,
              'role': role,
            });
          }
        }
      }
      return invitations;
    } catch (e) {
      print('Error obteniendo invitaciones: $e');
      return [];
    }
  }

  Future<void> respondToInvitation(
      String category, String ownerId, String userEmail, bool accept) async {
    try {
      final response = await _supabase
          .from('nayeka memories')
          .select()
          .eq('user_id', ownerId)
          .eq('category', category);

      for (var item in response) {
        Map<String, dynamic> currentPending = {};
        if (item['pending_roles'] != null) {
          currentPending = Map<String, dynamic>.from(item['pending_roles']);
        }

        Map<String, dynamic> currentRoles = {};
        if (item['shared_roles'] != null) {
          currentRoles = Map<String, dynamic>.from(item['shared_roles']);
        }

        List<String> currentShared = [];
        if (item['shared_with'] != null) {
          for (var e in item['shared_with']) {
            currentShared.add(e.toString());
          }
        }

        if (currentPending.containsKey(userEmail)) {
          String role = currentPending[userEmail];
          currentPending.remove(userEmail);

          if (accept) {
            currentRoles[userEmail] = role;
            bool yaCompartido = false;
            for (var email in currentShared) {
              if (email == userEmail) {
                yaCompartido = true;
                break;
              }
            }
            if (!yaCompartido) {
              currentShared.add(userEmail);
            }
          }

          await _supabase.from('nayeka memories').update({
            'pending_roles': currentPending,
            'shared_roles': currentRoles,
            'shared_with': currentShared,
          }).eq('id', item['id']);
        }
      }
    } catch (e) {
      print('Error respondiendo a invitación: $e');
      throw Exception('No se pudo procesar la invitación');
    }
  }

  Future<void> verifyStorageBucket() async {
    try {
      await _supabase.storage.from(_storageBucket).list();
    } catch (e) {
      if (e is StorageException && e.message.contains('not found')) {
        print('El bucket "$_storageBucket" no existe. Créalo en Supabase Dashboard > Storage');
      } else {
        print('Error accediendo al bucket: $e');
      }
    }
  }

  Future<void> testSupabaseConnection() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('Usuario no autenticado');
        return;
      }

      await verifyStorageBucket();

      final response = await _supabase
          .from('nayeka memories')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
    } catch (e) {
      print('Error en testSupabaseConnection: $e');
    }
  }
}

// Extensión para copiar Memory (sin usar ??)
extension MemoryCopyWith on Memory {
  T _valor<T>(T? nuevo, T actual) {
    if (nuevo != null) {
      return nuevo;
    } else {
      return actual;
    }
  }

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
    String? creatorId,
    Map<String, dynamic>? sharedRoles,
    Map<String, dynamic>? pendingRoles,
    String? creatorEmail,
  }) {
    return Memory(
      id: _valor(id, this.id),
      title: _valor(title, this.title),
      description: _valor(description, this.description),
      date: _valor(date, this.date),
      location: _valor(location, this.location),
      imageAsset: _valor(imageAsset, this.imageAsset),
      category: _valor(category, this.category),
      isFavorite: _valor(isFavorite, this.isFavorite),
      sharedWith: _valor(sharedWith, this.sharedWith),
      hasPassword: _valor(hasPassword, this.hasPassword),
      passwordHash: _valor(passwordHash, this.passwordHash),
      creatorId: _valor(creatorId, this.creatorId),
      sharedRoles: _valor(sharedRoles, this.sharedRoles),
      pendingRoles: _valor(pendingRoles, this.pendingRoles),
      creatorEmail: _valor(creatorEmail, this.creatorEmail),
    );
  }
}