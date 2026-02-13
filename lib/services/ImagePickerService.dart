import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  // Para elegir la imagen de la galería
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (kIsWeb && image != null) {
        return image.path;
      }
      
      return image?.path;
    } catch (e) {
      if (kDebugMode) {
        print('Error en pickImageFromGallery: $e');
      }
      return null;
    }
  }

  // Para subir una foto directamente sacada con la cámara
  Future<String?> pickImageFromCamera() async {
    try {
      if (kIsWeb) {
        return pickImageFromGallery();
      }
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      return image?.path;
    } catch (e) {
      if (kDebugMode) {
        print('Error en pickImageFromCamera: $e');
      }
      return null;
    }
  }

  // Método específico para web
  Future<String?> pickImageForWeb() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      return image?.path;
    } catch (e) {
      if (kDebugMode) {
        print('Error en pickImageForWeb: $e');
      }
      return null;
    }
  }

// Seleccionar video desde la galeria
  Future<String?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 20), // Límite de 20 segundos
      );
      return video?.path;
    } catch (e) {
      if (kDebugMode) print('Error en pickVideoFromGallery: $e');
      return null;
    }
  }

  // Grabar video con la cámara
  Future<String?> pickVideoFromCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 20), // Límite de 20 segundos
        preferredCameraDevice: CameraDevice.rear,
      );
      return video?.path;
    } catch (e) {
      if (kDebugMode) print('Error en pickVideoFromCamera: $e');
      return null;
    }
  }

  // Método para obtener bytes tanto de imágenes como de videos
  Future<Uint8List?> getFileBytes(String path) async {
    try {
      // Si es Web, el path suele ser un Blob URL o similar,pero para subir necesitamos leer el XFile original. 
      // Como no guardamos el XFile en el estado global, en Web la subida de video requiere un truco extra en el formulario,
      // pero para móvil esto funciona perfecto:
      if (!kIsWeb) {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo bytes: $e');
      return null;
    }
  }

  // Método necesario pq en web no existe File(path)
  Future<Uint8List?> pickVideoBytesForWeb() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 20),
      );
      
      if (video != null) {
        return await video.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error en pickVideoBytesForWeb: $e');
      return null;
    }
  }

  Future<Uint8List?> pickImageBytesForWeb() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (image != null) {
        return await image.readAsBytes();
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error en pickImageBytesForWeb: $e');
      return null;
    }
  }

  // Método universal que devuelve bytes para cualquier plataforma
  Future<Uint8List?> pickImageAsBytes() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        return bytes;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en pickImageAsBytes: $e');
      }
      return null;
    }
  }

  // Método para convertir path a bytes (para mobile/desktop)
  Future<Uint8List?> getBytesFromPath(String path) async {
    try {
      if (kIsWeb) {
        // En web, no podemos leer archivos del sistema
        return null;
      }
      
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en getBytesFromPath: $e');
      }
      return null;
    }
  }
}