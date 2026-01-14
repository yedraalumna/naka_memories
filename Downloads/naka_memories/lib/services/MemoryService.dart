import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/Memory.dart';

class MemoryService {
  static const String _memoriesKey = 'memories';

  // 1. obtenemos todos los recuerdos
  Future<List<Memory>> getMemories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoriesJson = prefs.getStringList(_memoriesKey) ?? [];

      return memoriesJson.map((json) {
        try {
          final map = jsonDecode(json);
          return Memory.fromMap(map);
        } catch (e) {
          print('Error parsing memory: $e');
          return Memory(
            id: 'error',
            title: 'Error',
            description: 'Error loading memory',
            date: '',
            location: {'latitude': 0.0, 'longitude': 0.0},
            imageAsset: null,
          );
        }
      }).toList();
    } catch (e) {
      print('Error cargando recuerdos: $e');
      return [];
    }
  }

  // 2. guardamos/actualizamos el recuerdo
  Future<void> saveMemory(Memory memory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Memory> memories = await getMemories();

      // Generamos el ID si no existe
      String memoryId;
      if (memory.id.isEmpty) {
        memoryId = DateTime.now().millisecondsSinceEpoch.toString();
      } else {
        memoryId = memory.id;
      }

      // Creamos el objeto final con ID
      final finalMemory = Memory(
        id: memoryId,
        title: memory.title,
        description: memory.description,
        date: memory.date,
        location: memory.location,
        imageAsset: memory.imageAsset ?? 'assets/images/default_memory.jpg',
      );

      // Buscamos si ya existe
      final existingIndex = memories.indexWhere((m) => m.id == memoryId);

      if (existingIndex >= 0) {
        // Actualizamos los existente
        memories[existingIndex] = finalMemory;
      } else {
        // Agregamos uno nuevo
        memories.add(finalMemory);
      }

      // Convertimos la lista de objetos a JSON y guardamos
      final memoriesJson = memories.map((m) => jsonEncode(m.toMap())).toList();
      await prefs.setStringList(_memoriesKey, memoriesJson);

    } catch (e) {
      print('Error guardando recuerdo: $e');
      throw Exception('No se pudo guardar el recuerdo: $e');
    }
  }

  // 3. eliminamos el recuerdo
  Future<void> deleteMemory(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Memory> memories = await getMemories();

      // Filtramos, eliminando el recuerdo con el ID
      final updatedMemories = memories.where((m) => m.id != id).toList();

      // Guardamos la lista actualizada
      final memoriesJson = updatedMemories.map((m) => jsonEncode(m.toMap())).toList();
      await prefs.setStringList(_memoriesKey, memoriesJson);

    } catch (e) {
      print('Error eliminando recuerdo: $e');
      throw Exception('No se pudo eliminar el recuerdo: $e');
    }
  }

  // 4. eliminamos todos los recuerdos
  Future<void> clearAllMemories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_memoriesKey);
    } catch (e) {
      print('Error limpiando todos los recuerdos: $e');
      throw Exception('No se pudieron eliminar todos los recuerdos: $e');
    }
  }
}