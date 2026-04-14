import 'package:flutter/material.dart';
import '../models/Memory.dart';
import '../services/MemoryService.dart';
import '../services/geocoding_service.dart';

class MemoryProvider extends ChangeNotifier {
  final MemoryService _memoryService = MemoryService();
  final GeocodingService _geocodingService = GeocodingService();
  
  List<Memory> _memories = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Cache para  el geocoding para que no haga peticiones repetidas

    //MODIFICAMOS AQUI
  final Map<String, String> _paisCache = {};
  final Map<String, String> _ciudadCache = {};
  final Map<String, String> _continenteCache = {};

  // Getters
  //MODIFICAMOS AQUI
  List<Memory> get memories => _memories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Países que se han visitados   //MODIFICAMOS AQUI hacemos mas secillo el metodo
  int get paisesUnicos {
    final paises = <String>{};
    for (var memory in _memories) {
      final key = '${memory.latitude},${memory.longitude}';
      final pais = _paisCache[key];
      if (pais != null && pais.isNotEmpty) {
        paises.add(pais);
      }
    }
    return paises.length;
  }

  // Ciudades que han sido visitadas
  int get ciudadesUnicas {
    final ciudades = <String>{};
    for (var memory in _memories) {
      final key = '${memory.latitude},${memory.longitude}';
      final ciudad = _ciudadCache[key];
      if (ciudad != null && ciudad.isNotEmpty) {
        ciudades.add(ciudad);
      }
    }
    return ciudades.length;
  }

  // Países agrupados por continente
  Map<String, Set<String>> get paisesPorContinente {
    final mapa = <String, Set<String>>{};
    for (var memory in _memories) {
      final key = '${memory.latitude},${memory.longitude}';
      final pais = _paisCache[key];
      final continente = _continenteCache[key];
      
      if (pais != null && pais.isNotEmpty && 
          continente != null && continente.isNotEmpty) {
        mapa.putIfAbsent(continente, () => <String>{});
        mapa[continente]!.add(pais);
      }
    }
    return mapa;
  }

  // Ciudades agrupadas por continente
  Map<String, Set<String>> get ciudadesPorContinente {
    final mapa = <String, Set<String>>{};
    for (var memory in _memories) {
      final key = '${memory.latitude},${memory.longitude}';
      final ciudad = _ciudadCache[key];
      final continente = _continenteCache[key];
      
      if (ciudad != null && ciudad.isNotEmpty &&  continente != null && continente.isNotEmpty) {
        //MODIFICAMOS AQUI
        mapa.putIfAbsent(continente, () => <String>{});
        mapa[continente]!.add(ciudad);
      }
    }
    return mapa;
  }
  
  Future<void> _geocodeMemory(Memory memory) async {
    final key = '${memory.latitude},${memory.longitude}';
    
    // Si ya tenemos caché, no geocodificamos de nuevo
    if (_paisCache.containsKey(key)) return;
    
    try {
      final lugar = await _geocodingService.getPlaceFromCoordinates(
        memory.latitude,
        memory.longitude,
      );
      
      if (lugar != null) {

          //MODIFICAMOS AQUI
        _paisCache[key] = lugar['pais'] ?? 'Desconocido';
        _ciudadCache[key] = lugar['ciudad'] ?? 'Desconocido';
        _continenteCache[key] = lugar['continente'] ?? 'Desconocido';
      } else {
        _paisCache[key] = 'Desconocido';
        _ciudadCache[key] = 'Desconocido';
        _continenteCache[key] = 'Desconocido';
      }
    } catch (e) {
      print('Error geocodificando: $e');
      _paisCache[key] = 'Desconocido';
      _ciudadCache[key] = 'Desconocido';
      _continenteCache[key] = 'Desconocido';
    }
  }

  // Geocodificamos todos los recuerdos
  Future<void> _geocodeAllMemories() async {
    for (var memory in _memories) {
      await _geocodeMemory(memory);
    }
    notifyListeners();
  }
  
  // Cargamos todos los recuerdos del usuario
  Future<void> loadMemories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _memories = await _memoryService.getMemories();
      print('MemoryProvider: ${_memories.length} recuerdos cargados');
      
      // Geocodificar después de cargar
      await _geocodeAllMemories();
      
    } catch (e) {
      print('Error cargando recuerdos: $e');
      _errorMessage = 'Error al cargar tus recuerdos';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Limpiamos el error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Limpiar caché ya aue es util cuando se cierra sesión
  void clearCache() {
    _paisCache.clear();
    _ciudadCache.clear();
    _continenteCache.clear();
  }
}