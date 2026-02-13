import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import '../constants/colors.dart';

class MemoryThumbnail extends StatelessWidget {
  final String? imagePath;
  final double width;
  final double height;
  final double borderRadius;

  const MemoryThumbnail({
    super.key,
    required this.imagePath,
    this.width = 60,
    this.height = 60,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Limpieza y validación básica
    final path = imagePath?.trim();

    // Si no hay ruta, mostramos el placeholder gris
    if (path == null || path.isEmpty) {
      return _buildContainer(
        color: pinkLighter,
        child: Icon(Icons.image_not_supported, color: pinkPrimary, size: 20),
      );
    }

    // 2. DETECCIÓN DE VIDEO
    if (path.toLowerCase().contains('mp4') ||
        path.toLowerCase().contains('mov')) {
      return _buildContainer(
        color: Colors.black87,
        // Usamos LayoutBuilder para que el tamaño sea relativo al espacio real
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Tomamos la dimensión más pequeña del hueco disponible (ancho o alto)
            // y hacemos que el icono ocupe la mitad de ese espacio real.
            double size = (constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight) *
                0.5;

            return Icon(
              Icons.play_circle_fill,
              color: Colors.white.withOpacity(0.9),
              size: size, // El tamaño ahora siempre será finito
            );
          },
        ),
      );
    }

    // 3. DETECCIÓN DE FOTO

    // A) Foto remota (Internet/Supabase)
    if (path.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          path,
          key: ValueKey(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          // Esto obliga al móvil a cargar una versión minúscula de la foto en memoria.
          // Si quitas esto, las fotos 4K de Supabase colapsan la lista del móvil (pantalla gris).
          cacheWidth: 150,

          loadingBuilder: (ctx, child, loading) {
            if (loading == null) return child;
            return _buildContainer(
              color: Colors.grey[200]!,
              child: const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: pinkPrimary)),
            );
          },
          errorBuilder: (ctx, err, stack) {
            print('Error cargando imagen ($path): $err');
            return _buildContainer(
              color: Colors.red.withOpacity(0.1),
              child: Icon(Icons.broken_image, color: Colors.red, size: 20),
            );
          },
        ),
      );
    }

    // B) Foto local (Assets)
    if (path.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          path,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildContainer(color: pinkLighter, child: Icon(Icons.error)),
        ),
      );
    }

    // C) Foto local (Archivo del móvil)
    File file = File(path);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: 150, // Optimización también para locales
          errorBuilder: (_, __, ___) =>
              _buildContainer(color: pinkLighter, child: Icon(Icons.error)),
        ),
      );
    }

    // Si nada funciona:
    return _buildContainer(
      color: Colors.grey,
      child: Icon(Icons.help_outline, color: Colors.white),
    );
  }

  // Helper para construir los cajitas redondeadas
  Widget _buildContainer({required Color color, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: color,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
