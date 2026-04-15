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
  final Map<String, String> _paisCache = {};
  final Map<String, String> _ciudadCache = {};
  final Map<String, String> _continenteCache = {};

  // Getters
  List<Memory> get memories {
    return _memories;
  }

  bool get isLoading {
    return _isLoading;
  }

  String? get errorMessage {
    return _errorMessage;
  }

  // Países que se han visitados
  int get paisesUnicos {
    // Lista para guardar países sin repetir
    List<String> paisesLista = [];

    // Revisamos cada recuerdo
    for (var memory in _memories) {
      // Obtenemos las coordenadas
      double lat = memory.latitude;
      double lng = memory.longitude;
      String clave = '$lat,$lng';

      // Buscamos el el país
      String? pais = _paisCache[clave];

      // Si hay país y no está vacío
      if (pais != null) {
        if (pais != "") {
          // Si no está en la lista, lo añadimos
          bool yaExiste = paisesLista.contains(pais);
          if (yaExiste == false) {
            paisesLista.add(pais);
          }
        }
      }
    }

    // Devolvemos la cantidad
    return paisesLista.length;
  }

  // Ciudades que se han visitado
  int get ciudadesUnicas {
    // Lista para guardar ciudades sin repetir
    List<String> ciudadesLista = [];

    // Revisamos cada recuerdo
    for (var memory in _memories) {
      // Obtenemos las coordenadas
      double lat = memory.latitude;
      double lng = memory.longitude;
      String clave = '$lat,$lng';

      // Buscamos la ciudad
      String? ciudad = _ciudadCache[clave];

      // Si hay ciudad y no está vacía
      if (ciudad != null) {
        if (ciudad != "") {
          // Si no está en la lista, la añadimos
          bool yaExiste = ciudadesLista.contains(ciudad);
          if (yaExiste == false) {
            ciudadesLista.add(ciudad);
          }
        }
      }
    }

    // Devolvemos la cantidad
    return ciudadesLista.length;
  }

  // Países agrupados por continente
  Map<String, Set<String>> get paisesPorContinente {
    // Mapa para guardar: continente → lista de países
    Map<String, Set<String>> mapa = {};

    // Revisamos cada recuerdo
    for (var memory in _memories) {
      // Obtenemos las coordenadas
      double lat = memory.latitude;
      double lng = memory.longitude;
      String clave = '$lat,$lng';

      // Buscamos el país y el continente
      String? pais = _paisCache[clave];
      String? continente = _continenteCache[clave];

      // Verificamos si tenemos país válido
      if (pais != null) {
        if (pais.isNotEmpty) {
          // Verificamos si tenemos continente válido
          if (continente != null) {
            if (continente.isNotEmpty) {
              // Si el continente no existe en el mapa, lo creamos
              if (mapa.containsKey(continente) == false) {
                mapa[continente] = <String>{};
              }

              // Añadimos el país al continente
              Set<String> paisesDelContinente = mapa[continente]!;
              paisesDelContinente.add(pais);
            }
          }
        }
      }
    }

    return mapa;
  }

  // Ciudades agrupadas por continente
  Map<String, Set<String>> get ciudadesPorContinente {
    // Mapa para guardar continente a lista de ciudades
    Map<String, Set<String>> mapa = {};

    // Revisamos cada recuerdo
    for (var memory in _memories) {
      // Obtenemos las coordenadas
      double lat = memory.latitude;
      double lng = memory.longitude;
      String clave = '$lat,$lng';

      // Buscamos la ciudad y el continente
      String? ciudad = _ciudadCache[clave];
      String? continente = _continenteCache[clave];

      // Verificamos si tenemos ciudad válida
      if (ciudad != null) {
        if (ciudad.isNotEmpty) {
          // Verificamos si tenemos continente válido
          if (continente != null) {
            if (continente.isNotEmpty) {
              // Si el continente no existe en el mapa, lo creamos
              if (mapa.containsKey(continente) == false) {
                mapa[continente] = <String>{};
              }

              // Añadimos la ciudad al continente
              Set<String> ciudadesDelContinente = mapa[continente]!;
              ciudadesDelContinente.add(ciudad);
            }
          }
        }
      }
    }

    return mapa;
  }

  Future<void> _geocodeMemory(Memory memory) async {
  // Creamos una clave con las coordenadas del recuerdo
  String clave = '${memory.latitude},${memory.longitude}';

  // Si ya tenemos el país en cache, no volvemos a buscar
  if (_paisCache.containsKey(clave) == true) {
    return;
  }

  try {
    // Pedimos la información del lugar como el pais, ciudad o continente
    final lugar = await _geocodingService.getPlaceFromCoordinates(
      memory.latitude,
      memory.longitude,
    );

    if (lugar != null) {
      // guardamos el pais
      String? pais = lugar['pais'];
      if (pais != null) {
        _paisCache[clave] = pais;
      } else {
        _paisCache[clave] = 'Desconocido';
      }
      
      // guardamos la ciudad
      String? ciudad = lugar['ciudad'];
      if (ciudad != null) {
        _ciudadCache[clave] = ciudad;
      } else {
        _ciudadCache[clave] = 'Desconocido';
      }
      
      // guardamos el continente
      String? continente = lugar['continente'];
      if (continente != null) {
        _continenteCache[clave] = continente;
      } else {
        _continenteCache[clave] = 'Desconocido';
      }
    } else {
      // Si no hay información, guardamos "Desconocido"
      _paisCache[clave] = 'Desconocido';
      _ciudadCache[clave] = 'Desconocido';
      _continenteCache[clave] = 'Desconocido';
    }
  } catch (e) {
    // Si hay error, guardamos "Desconocido"
    print('Error geocodificando: $e');
    _paisCache[clave] = 'Desconocido';
    _ciudadCache[clave] = 'Desconocido';
    _continenteCache[clave] = 'Desconocido';
  }
}

  // Geocodificamos todos los recuerdos
  Future<void> _geocodeAllMemories() async {
     //Recorremos cada recuerdo
    for (var memory in _memories) {
      // Buscamos la información del lugar como el pais, ciudad y continente
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

      // Geocodificamos después de cargar
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

  // Limpiamos caché ya que es util cuando se cierra sesión
  void clearCache() {
    _paisCache.clear();
    _ciudadCache.clear();
    _continenteCache.clear();
  }
}