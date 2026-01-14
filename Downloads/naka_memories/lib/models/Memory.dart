import 'package:google_maps_flutter/google_maps_flutter.dart';

class Memory {
  final String id;
  final String title;
  final String description;
  final String date;
  final Map<String, double> location;
  final String? imageAsset; //es necesario el ?

  Memory({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    this.imageAsset,
  });

  // getters
  double get latitude => location['latitude'] as double;
  double get longitude => location['longitude'] as double;

  LatLng get toLatLng => LatLng(latitude, longitude);

  //convertimos el objeto Memory a un Map para ser almacenado
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

  //Creamos una instancia de Memory a partir de un Map
  static Memory fromMap(Map<String, dynamic> map) {
    return Memory(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      date: map['date'] as String,
      location: {
        'latitude': (map['latitude'] as num).toDouble(),
        'longitude': (map['longitude'] as num).toDouble(),
      },
      imageAsset: map['imageAsset'] as String,
    );
  }
}