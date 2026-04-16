import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

// Widget que muestra una miniatura (imagen pequeña) para un recuerdo.
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

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();

    Widget content;

    // Caso 1: No hay ruta de imagen
    if (path == null || path.isEmpty) {
      content = _buildContainer(
        color: pinkLighter,
        child: const Icon(Icons.image_not_supported, color: pinkPrimary, size: 20),
      );
    }
    // Caso 2: Es un video
    else if (path.toLowerCase().contains('mp4') ||
        path.toLowerCase().contains('mov')) {
      content = _buildContainer(
        color: Colors.black87,
        child: LayoutBuilder(
          builder: (context, constraints) {
            double size;
            if (constraints.maxWidth < constraints.maxHeight) {
              size = constraints.maxWidth * 0.5;
            } else {
              size = constraints.maxHeight * 0.5;
            }
            return Icon(
              Icons.play_circle_fill,
              color: Colors.white.withOpacity(0.9),
              size: size,
            );
          },
        ),
      );
    }
    // Caso 3: Imagen de internet
    else if (path.startsWith('http')) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          path,
          key: ValueKey(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: 150,
          loadingBuilder: (ctx, child, loading) {
            if (loading == null) {
              return child;
            } else {
              return _buildContainer(
                color: Colors.grey[200]!,
                child: const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: pinkPrimary
                  ),
                ),
              );
            }
          },
          errorBuilder: (ctx, err, stack) => _buildContainer(
            color: Colors.red.withOpacity(0.1),
            child: const Icon(Icons.broken_image, color: Colors.red, size: 20),
          ),
        ),
      );
    }
    // Caso 4: Asset interno
    else if (path.startsWith('assets/')) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          path,
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }
    // Caso 5: Archivo local
    else {
      File file = File(path);
      if (file.existsSync()) {
        content = ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: 150,
          ),
        );
      } else {
        content = _buildContainer(
          color: Colors.grey,
          child: const Icon(Icons.help_outline, color: Colors.white)
        );
      }
    }

    return content;
  }
}