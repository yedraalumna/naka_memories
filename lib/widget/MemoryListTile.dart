import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/Memory.dart';
import '../providers/favorite_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import 'MemoryThumbnail.dart';
import 'MemoryDetailScreen.dart';

// Widget que muestra un recuerdo como una tarjeta en una lista
class MemoryListTile extends StatelessWidget {
  final Memory memory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(Memory) onUpdate;

  const MemoryListTile({
    super.key,
    required this.memory,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isFav = context.watch<FavoriteProvider>().isFavorite(memory.id);

    // Colores según el tema
    Color colorTarjeta;
    Color colorTitulo;
    Color colorSubtitulo;
    
    if (themeProvider.isDarkMode == true) {
      colorTarjeta = cardDark;
      colorTitulo = textDarkMode;
      colorSubtitulo = Colors.grey[400]!;
    } else {
      colorTarjeta = Colors.white;
      colorTitulo = Colors.black87;
      colorSubtitulo = Colors.grey[600]!;
    }

    // Icono del botón favorito
    Icon iconoFavorito;
    if (isFav == true) {
      iconoFavorito = const Icon(Icons.favorite, color: pinkPrimary);
    } else {
      iconoFavorito = const Icon(Icons.favorite_border, color: Colors.grey);
    }

    return Card(
      elevation: 2,
      color: colorTarjeta,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: MemoryThumbnail(
          imagePath: memory.imageAsset,
          width: 60,
          height: 60,
          borderRadius: 8,
        ),
        title: Text(
          memory.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorTitulo,
          ),
        ),
        subtitle: Text(
          memory.date,
          style: TextStyle(
            color: colorSubtitulo,
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          icon: iconoFavorito,
          onPressed: () {
            context.read<FavoriteProvider>().toggleFavorite(memory.id);
          },
        ),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return MemoryDetailScreen(
                memory: memory,
                onEdit: onEdit,
                onDelete: onDelete,
                onUpdate: onUpdate,
              );
            },
          );
        },
      ),
    );
  }
}