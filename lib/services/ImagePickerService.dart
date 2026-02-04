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

  // NUEVO MÉTODO: Para obtener bytes de imagen en web
  Future<Uint8List?> pickImageBytesForWeb() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (image != null) {
        // Leer como bytes
        final bytes = await image.readAsBytes();
        return bytes;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en pickImageBytesForWeb: $e');
      }
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