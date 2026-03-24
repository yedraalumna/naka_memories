import 'package:google_maps_flutter/google_maps_flutter.dart';

class Memory {
  final String id;
  final String title;
  final String description;
  final String date;
  final Map<String, double> location;
  final String? imageAsset;
  final String category;
  final bool isFavorite;
  final List<String> sharedWith;

  // Lista de las categorias
  static const List<String> categoriesList = [
    'General',
    'Viajes',
    'Amigos',
    'Familia',
    'Comida',
    'Estudio',
  ];

  Memory({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    this.imageAsset,
    this.category = 'Sin categoría',
    this.isFavorite = false,
    this.sharedWith = const [],
  });

  // getters SEGUROS
  double get latitude => location['latitude'] ?? 0.0;
  double get longitude => location['longitude'] ?? 0.0;

  LatLng get toLatLng => LatLng(latitude, longitude);

  // Getter para verificar si el asset es un video
  bool get isVideo {
    if (imageAsset == null) return false;
    final lowerCaseAsset = imageAsset!.toLowerCase();
    return lowerCaseAsset.contains('.mp4') || 
           lowerCaseAsset.contains('.mov') || 
           lowerCaseAsset.contains('.avi') ||
           lowerCaseAsset.contains('.mkv') ||
           lowerCaseAsset.contains('.webm');
  }

  // Getter para verificar si es una imagen
  bool get isImage {
    if (imageAsset == null) return false;
    if (isVideo) return false;
    final lowerCaseAsset = imageAsset!.toLowerCase();
    return lowerCaseAsset.contains('.jpg') || 
           lowerCaseAsset.contains('.jpeg') || 
           lowerCaseAsset.contains('.png') ||
           lowerCaseAsset.contains('.gif') ||
           lowerCaseAsset.contains('.bmp') ||
           lowerCaseAsset.contains('.webp');
  }

  // Getter para obtener el tipo de multimedia
  String get mediaType {
    if (imageAsset == null) return 'none';
    if (isVideo) return 'video';
    if (isImage) return 'image';
    return 'unknown';
  }

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
      'category': category,
      'isFavorite': isFavorite,
      'shared_with': sharedWith,
    };
  }

  // Creamos una instancia de Memory a partir de un Map
  factory Memory.fromMap(Map<String, dynamic> map) {
    try {
      // ID - siempre convertir a String, con valor por defecto
      final id = _safeString(map['id'],
          defaultValue: DateTime.now().millisecondsSinceEpoch.toString());

      // Title - con valor por defecto
      final title = _safeString(map['title'], defaultValue: 'Sin título');

      // Description - puede ser null
      final description = _safeString(map['description']);

      // Date - con valor por defecto
      final date = _safeString(map['date'],
          defaultValue: DateTime.now().toIso8601String());

      // Latitude y Longitude - manejar nulls y tipos
      final latitude = _safeDouble(map['latitude']);
      final longitude = _safeDouble(map['longitude']);

      // ImageAsset - puede ser null
      final imageAsset = map['imageAsset']?.toString();

      // Category - con valor por defecto
      final category =
          _safeString(map['category'], defaultValue: 'Sin categoría');

      // isFavorite - con valor por defecto
      final isFavorite =
          (map['isFavorite'] == true) || (map['is_favorite'] == true);

      // sharedRaw -Extraemos la lista de compartidos de forma segura
      final sharedRaw = map['shared_with'] ?? map['sharedWith'];
      List<String> parsedSharedWith = [];
      if (sharedRaw is List) {
        parsedSharedWith = sharedRaw.map((e) => e.toString()).toList();
      }    

      return Memory(
        id: id,
        title: title,
        description: description,
        date: date,
        location: {
          'latitude': latitude,
          'longitude': longitude,
        },
        imageAsset: imageAsset,
        category: category,
        isFavorite: isFavorite,
        sharedWith: parsedSharedWith,
      );
    } catch (e) {
      print('ERROR en Memory.fromMap: $e');
      return Memory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Recuerdo con error',
        description: 'Error al cargar este recuerdo',
        date: DateTime.now().toIso8601String(),
        location: {'latitude': 0.0, 'longitude': 0.0},
        imageAsset: null,
        category: 'General',
        isFavorite: false,
        sharedWith: [],
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

  // Método para crear una copia con valores actualizados
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
    );
  }

  // Método opcional para debug
  @override
  String toString() {
    return 'Memory{id: $id, title: $title, date: $date, lat: $latitude, lng: $longitude, image: $imageAsset, category: $category, isFavorite: $isFavorite, mediaType: $mediaType, sharedWith: $sharedWith}';
  }

  // Método para comparar dos memorias
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Memory &&
        other.id == id &&
        other.title == title &&
        other.date == date;
  }

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ date.hashCode;
}