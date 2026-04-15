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
  final bool hasPassword;
  // los siguientes campos son opcionales y pueden ser nulos, por eso los marcamos con '?'
  final String? passwordHash;
  final String? creatorId;
  final Map<String, dynamic>? sharedRoles;
  final Map<String, dynamic>? pendingRoles;
  final String? creatorEmail;

  // Lista de las categorias predeterminadas
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
    this.hasPassword = false,
    this.passwordHash,
    this.creatorId,
    this.sharedRoles,
    this.pendingRoles,
    this.creatorEmail,
  });

  static const List<String> defaultCategories = [
    'General',
    'Viajes',
    'Amigos',
    'Familia',
    'Comida',
    'Estudio',
  ];

  // getters
  double get latitude {
    final valor = location['latitude'];
    if (valor != null) {
      return valor;
    }
    return 0.0;
  }

  double get longitude {
    final valor = location['longitude'];
    if (valor != null) {
      return valor;
    }
    return 0.0;
  }

  LatLng get toLatLng {
    return LatLng(latitude, longitude);
  }

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

  // Convertimos el objeto memory a un map para que se almacene
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
      'has_password': hasPassword,
      'password_hash': passwordHash,
      'user_id': creatorId,
      'shared_roles': sharedRoles,
      'pending_roles': pendingRoles,
      'creator_email': creatorEmail,
    };
  }

  // Creamos una instancia de memory a partir de un map
  factory Memory.fromMap(Map<String, dynamic> map) {
    try {
      //datos básicos
      final id = _safeString(map['id'],
          defaultValue: DateTime.now().millisecondsSinceEpoch.toString());
      final title = _safeString(map['title'], defaultValue: 'Sin título');
      final description = _safeString(map['description']);
      final date = _safeString(map['date'],
          defaultValue: DateTime.now().toIso8601String());
      final latitude = _safeDouble(map['latitude']);
      final longitude = _safeDouble(map['longitude']);

      // imageAsset puede ser null
      String? imageAsset;
      if (map['imageAsset'] != null) {
        imageAsset = map['imageAsset'].toString();
      }

      final category =
          _safeString(map['category'], defaultValue: 'Sin categoría');
      final isFavorite =
          (map['isFavorite'] == true) || (map['is_favorite'] == true);

      // Buscamos la lista de usuarios compartidos
      dynamic sharedRaw = map['shared_with'];
      if (sharedRaw == null) {
        sharedRaw = map['sharedWith'];
      }

      List<String> parsedSharedWith = [];
      if (sharedRaw is List) {
        for (var item in sharedRaw) {
          parsedSharedWith.add(item.toString());
        }
      }

      // la contraseña se determina por el hash, si el hash existe y no es vacío, entonces hay contraseña
      final hasPassword =
          (map['has_password'] == true) || (map['hasPassword'] == true);

      // Buscamos el hash de la contraseña
      String? passwordHash;
      dynamic hash1 = map['password_hash'];
      dynamic hash2 = map['passwordHash'];

      if (hash1 != null) {
        passwordHash = hash1.toString();
      } else {
        if (hash2 != null) {
          passwordHash = hash2.toString();
        }
      }

      // Buscamos el ID del creador
      dynamic creador = map['user_id'];
      if (creador == null) {
        creador = map['creatorId'];
      }
      final creatorId = _safeString(creador);

      // Buscamos el email del creador
      dynamic emailCreador = map['creator_email'];
      if (emailCreador == null) {
        emailCreador = map['creatorEmail'];
      }

      final creatorEmail = _safeString(emailCreador);

      // Buscamos los roles compartidos
      dynamic rolesRaw = map['shared_roles'];
      if (rolesRaw == null) {
        rolesRaw = map['sharedRoles'];
      }

      Map<String, dynamic>? parsedSharedRoles;
      if (rolesRaw is Map) {
        parsedSharedRoles = Map<String, dynamic>.from(rolesRaw);
      }

      // Buscamos los roles pendientes
      dynamic pendingRaw = map['pending_roles'];
      if (pendingRaw == null) {
        pendingRaw = map['pendingRoles'];
      }

      Map<String, dynamic>? parsedPendingRoles;
      if (pendingRaw is Map) {
        parsedPendingRoles = Map<String, dynamic>.from(pendingRaw);
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
        hasPassword: hasPassword,
        passwordHash: passwordHash,
        creatorId: creatorId,
        sharedRoles: parsedSharedRoles,
        pendingRoles: parsedPendingRoles,
        creatorEmail: creatorEmail,
      );
    } catch (e) {
      print('Error en Memory.fromMap: $e');
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
        hasPassword: false,
        passwordHash: null,
        creatorId: null,
        sharedRoles: null,
        pendingRoles: null,
        creatorEmail: null,
      );
    }
  }

  // Helper para convertir a String de forma segura
  static String _safeString(dynamic value, {String defaultValue = ''}) {
    // Si el valor es null, devolvemos el valor por defecto
    if (value == null) {
      return defaultValue;
    }

    // Si ya es un texto, lo devolvemos tal cual
    if (value is String) {
      return value;
    }

    // Si es otro tipo como número, booleano, etc, lo convertimos a texto
    return value.toString();
  }

  // Helper para convertir a double de forma segura
  static double _safeDouble(dynamic value, {double defaultValue = 0.0}) {
    // miramos si esta vacio
    if (value == null) {
      return defaultValue; // Si sí, devuelve 0
    }

    // miramos si es un numero decimal
    if (value is double) {
      return value; // Lo devuelve tal cual
    }

    // miramos si es un numero entero
    if (value is int) {
      return value.toDouble(); // Lo convierte a decimal (40 → 40.0)
    }

    // miramos si es un texto que representa un número
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return defaultValue; // Si no es número, devuelve 0
      }
    }

    // Cualquier otro caso, devuelve 0
    return defaultValue;
  }

  //Devuelve el nuevo valor si no es nulo, si no, devuelve el valor actual
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

  // Método para comparar dos memorias
  @override
  bool operator ==(Object other) {
    //miramos si es el mismo objeto
    if (identical(this, other) == true) {
      return true;
    }

    // miramos si es del mismo tipo
    if (other is Memory) {
      // camparamos el id
      if (other.id != id) {
        return false;
      }
      // camparamos el titulo
      if (other.title != title) {
        return false;
      }
      // camparamos la fecha
      if (other.date != date) {
        return false;
      }
      // Si pasó todas las comparaciones, son iguales
      return true;
    }

    // Si no es un Memory, son diferentes
    return false;
  }

  @override
  int get hashCode {
    // Obtenemos el código de cada parte
    int codigoId = id.hashCode;
    int codigoTitulo = title.hashCode;
    int codigoFecha = date.hashCode;

    // Los combinamos de forma sencilla
    int resultado = codigoId + codigoTitulo + codigoFecha;
    return resultado;
  }
}
