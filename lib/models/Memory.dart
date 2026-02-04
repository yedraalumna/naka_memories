import 'package:google_maps_flutter/google_maps_flutter.dart';

class Memory {
  final String id;
  final String title;
  final String description;
  final String date;
  final Map<String, double> location;
  final String? imageAsset; // ✅ El ? es CORRECTO porque puede ser null

  Memory({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    this.imageAsset, // ✅ Mantiene el ?
  });

  // getters SEGUROS
  double get latitude => location['latitude'] ?? 0.0;
  double get longitude => location['longitude'] ?? 0.0;

  LatLng get toLatLng => LatLng(latitude, longitude);

  // Convertimos el objeto Memory a un Map para ser almacenado
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'latitude': latitude,
      'longitude': longitude,
      'imageAsset': imageAsset,
    };
  }

  // Creamos una instancia de Memory a partir de un Map - VERSIÓN SEGURA
  factory Memory.fromMap(Map<String, dynamic> map) {
    try {
      // ID - siempre convertir a String, con valor por defecto
      final id = _safeString(map['id'], defaultValue: DateTime.now().millisecondsSinceEpoch.toString());
      
      // Title - con valor por defecto
      final title = _safeString(map['title'], defaultValue: 'Sin título');
      
      // Description - puede ser null
      final description = _safeString(map['description']);
      
      // Date - con valor por defecto
      final date = _safeString(map['date'], defaultValue: DateTime.now().toIso8601String());
      
      // Latitude y Longitude - manejar nulls y tipos
      final latitude = _safeDouble(map['latitude']);
      final longitude = _safeDouble(map['longitude']);
      
      // ImageAsset - puede ser null
      final imageAsset = map['imageAsset']?.toString();

      return Memory(
        id: id,
        title: title,
        description: description,
        date: date,
        location: {
          'latitude': latitude,
          'longitude': longitude,
        },
        imageAsset: imageAsset, // ✅ Puede ser null
      );
    } catch (e) {
      print('❌ ERROR en Memory.fromMap: $e');
      print('Map que causó el error: $map');
      
      // Retornar un Memory seguro en caso de error
      return Memory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Recuerdo con error',
        description: 'Error al cargar este recuerdo',
        date: DateTime.now().toIso8601String(),
        location: {'latitude': 0.0, 'longitude': 0.0},
        imageAsset: null,
      );
    }
  }

  // Helper para convertir a String de forma segura
  static String _safeString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  // Helper para convertir a double de forma segura
  static double _safeDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  // Método opcional para debug
  @override
  String toString() {
    return 'Memory{id: $id, title: $title, date: $date, lat: $latitude, lng: $longitude, image: $imageAsset}';
  }
}