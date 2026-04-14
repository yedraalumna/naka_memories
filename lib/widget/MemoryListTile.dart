import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/Memory.dart';
import '../providers/favorite_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/colors.dart';
import 'MemoryThumbnail.dart';
import 'MemoryDetailScreen.dart';

class MemoryListTile extends StatelessWidget {
  final Memory memory;
  final VoidCallback onEdit; // Callback para la lógica de edición
  final VoidCallback onDelete; // Callback para la lógica de borrado
  final Function(Memory) onUpdate; // Callback para actualizar el recuerdo

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
    final isFav = context.watch<FavoriteProvider>().isFavorite(memory.id);

    return Card(
      elevation: 2,

       //MODIFCAMOS AQUI
      color: themeProvider.isDarkMode ? cardDark : Colors.white,
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

             //MODIFCAMOS AQUI
            color: themeProvider.isDarkMode ? textDarkMode : Colors.black87,
          ),
        ),
        subtitle: Text(
          memory.date,
          style: TextStyle(

             //MODIFCAMOS AQUI
            color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: IconButton(

           //MODIFCAMOS AQUI
          icon: Icon( isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? pinkPrimary : Colors.grey,),
          onPressed: () {
            context.read<FavoriteProvider>().toggleFavorite(memory.id);
          },
        ),
        onTap: () {
          // Abrimos el modal con la lógica de gestión de edición y borrado inyectada
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => MemoryDetailScreen(
              memory: memory,
              onEdit: onEdit,
              onDelete: onDelete,
              onUpdate: onUpdate,
            ),
          );
        },
      ),
    );
  }
}