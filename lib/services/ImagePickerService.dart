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
        imageQuality: 80, // Se reduce un poco la calidad para ahorrar espacio
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (kIsWeb && image != null) {
        // Para web, el path puede venir como blob URL o base64
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
        // En web, la cámara puede no estar disponible, así que usamos galería
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

  // Método específico para web (necesario para MemoryForm)
  Future<String?> pickImageForWeb() async {
    try {
      // En web, tanto cámara como galería usan el mismo método
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, // Usamos gallery para web
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
}