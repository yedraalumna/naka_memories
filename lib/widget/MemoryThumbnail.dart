import 'dart:io';
import 'package:flutter/material.dart';
// Para kIsWeb
import '../constants/colors.dart';

class MemoryThumbnail extends StatelessWidget {
  final String? imagePath;
  final double width;
  final double height;
  final double borderRadius;
  final bool isShared;

  const MemoryThumbnail({
    super.key,
    required this.imagePath,
    this.width = 60,
    this.height = 60,
    this.borderRadius = 8,
    this.isShared = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Limpieza y validación básica
    final path = imagePath?.trim();

    // Creamos el contenido base
    Widget content;

    if (path == null || path.isEmpty) {
      content = _buildContainer(
        color: pinkLighter,
        child:
            const Icon(Icons.image_not_supported, color: pinkPrimary, size: 20),
      );
    } else if (path.toLowerCase().contains('mp4') ||
        path.toLowerCase().contains('mov')) {
      content = _buildContainer(
        color: Colors.black87,
        child: LayoutBuilder(
          builder: (context, constraints) {
            double size = (constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight) *
                0.5;
            return Icon(
              Icons.play_circle_fill,
              color: Colors.white.withOpacity(0.9),
              size: size,
            );
          },
        ),
      );
    } else if (path.startsWith('http')) {
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
          errorBuilder: (ctx, err, stack) => _buildContainer(
            color: Colors.red.withOpacity(0.1),
            child: const Icon(Icons.broken_image, color: Colors.red, size: 20),
          ),
        ),
      );
    } else if (path.startsWith('assets/')) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          path,
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    } else {
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
            child: const Icon(Icons.help_outline, color: Colors.white));
      }
    }

    return Stack(
      children: [
        content,
        if (isShared)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black
                    .withOpacity(0.6), 
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people, 
                color: Colors.white,
                size: 20, 
              ),
            ),
          ),
      ],
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
