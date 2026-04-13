import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Este servicio se encarga de manejar la cámara, galería y explorador de archivos, asimismo la selección de fotos y videos.
/// Funciona como un asistente que se comunica con la cámara y galería del dispositivo
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Método que abre la galería del teléfono (o el explorador de archivos en web) para elegir una foto
  /// Devuelve la "ruta" donde está guardada la imagen
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality:
            80, // Bajamos la calidad un poco para que no tarde en subir
        maxWidth:
            1200, // Limitamos el tamaño para evitar que la app se quede sin memoria
        maxHeight: 1200,
      );

      // Retornamos el 'path.' Esto funciona tanto en móvil (ruta física)
      // como en web (que devuelve un "blob URL")
      return image?.path;
    } catch (e) {
      if (kDebugMode) {
        // Sirve para mostrar el error en 'modo debug' para no saturar los logs en producción
        print('Error en pickImageFromGallery: $e');
      }
      return null;
    }
  }

  /// Método que abre la cámara del dispositivo para tomar una foto al momento
  Future<String?> pickImageFromCamera() async {
    try {
      // En web la cámara es un poco especial, así que para evitar errores
      // se lleva al usuario al explorador de archivos directamente
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

  /// Método que abre la galería de videos, o en web el explorador de archivos
  Future<String?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(
            seconds: 20), // Cortamos en 20 segundos, formato reels
      );
      return video?.path;
    } catch (e) {
      if (kDebugMode) {
        print('Error en pickVideoFromGallery: $e');
      }
      return null;
    }
  }

  /// Método que abre la cámara para grabar un vídeo
  Future<String?> pickVideoFromCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 20),
        preferredCameraDevice:
            CameraDevice.rear, // Abrimos la cámara trasera por defecto
      );
      return video?.path;
    } catch (e) {
      if (kDebugMode) {
        print('Error en pickVideoFromCamera: $e');
      }
      return null;
    }
  }

  /// Método para subir videos desde la web
  /// como en web no sigue el mismo método que en movil/app, ya que no hay un disco duro real al que acceder
  /// este método pide el video y lo transforma en bytes para mandar al servidor o base de datos
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
      if (kDebugMode) {
        print('Error en pickVideoBytesForWeb: $e');
      }
      return null;
    }
  }

  /// Método que abre la galería (explorador de archivos), deja elegir una foto y devuelve los bytes
  /// Funciona en web, Android e ios.
  Future<Uint8List?> pickImageAsBytes() async {
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
      if (kDebugMode) {
        print('Error en pickImageAsBytes: $e');
      }
      return null;
    }
  }

  /// Método que lee un archivo guardado en el teléfono y lo convierte a "bytes" (datos crudos)
  /// Esto es obligatorio antes de mandar cualquier archivo a un servidor o base de datos
  Future<Uint8List?> getBytesFromPath(String path) async {
    try {
      // Como en la web no hay un disco duro real al que acceder,
      // esto solo se ejecuta si estamos en una app (móvil o escritorio)
      if (kIsWeb) return null;

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
