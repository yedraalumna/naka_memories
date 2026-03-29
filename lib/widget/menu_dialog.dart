import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import 'MemoryThumbnail.dart';
import '../services/pdfService.dart';
import '../providers/app_auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widget/pin_dialog.dart';

class MenuDialog extends StatefulWidget {
  final List<Memory> memories;
  final LatLng currentPosition;

  final VoidCallback onShowAllMemories;
  final VoidCallback onSaveCurrentCoordinates;
  final VoidCallback onCreateNewMemory;
  final VoidCallback onClearAllMemories;
  final Function(Memory) onShowMemoryDetails;
  final Function(List<Memory>) onCenterList;
  final VoidCallback onGenerarPdf;

  const MenuDialog({
    super.key,
    required this.memories,
    required this.currentPosition,
    required this.onShowAllMemories,
    required this.onSaveCurrentCoordinates,
    required this.onCreateNewMemory,
    required this.onClearAllMemories,
    required this.onShowMemoryDetails,
    required this.onCenterList,
    required this.onGenerarPdf,
  });

  @override
  State<MenuDialog> createState() => _MenuDialogState();
}

class _MenuDialogState extends State<MenuDialog> {

  void _showMemoryListModal(List<Memory> list, String title, ThemeData theme, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx2, scrollController) {
            Color backgroundColor = isDarkMode ? backgroundDark : Colors.white;
            Color textColor = isDarkMode ? Colors.white : Colors.black;
            Color primaryColor =
                theme.brightness == Brightness.dark ? pinkLight : pinkPrimary;

            return Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron recuerdos.',
                              style: TextStyle(color: textColor),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: list.length,
                            itemBuilder: (ctx3, index) {
                              final memory = list[index];
                              return ListTile(
                                leading: MemoryThumbnail(
                                  imagePath: memory.imageAsset,
                                  width: 50,
                                  height: 50,
                                ),
                                title: Text(
                                  memory.title,
                                  style: TextStyle(color: textColor),
                                ),
                                subtitle: Text(
                                  '${memory.date} | ${memory.location['latitude']?.toStringAsFixed(4)}, ${memory.location['longitude']?.toStringAsFixed(4)}',
                                  style: TextStyle(
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.grey[400]
                                          : Colors.grey[700]),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx3);
                                  widget.onShowMemoryDetails(memory);
                                },
                                tileColor: theme.brightness == Brightness.dark
                                    ? cardDark.withOpacity(0.5)
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSortedByDate(ThemeData theme, bool isDarkMode) {
    Navigator.pop(context);
    final sortedMemories = List<Memory>.from(widget.memories)
      ..sort((a, b) => b.date.compareTo(a.date));
    _showMemoryListModal(
        sortedMemories, 'Recuerdos por Fecha (Recientes)', theme, isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    bool isDarkMode;
    if (themeProvider.themeMode == ThemeMode.system) {
      isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    }

    Color backgroundColor = isDarkMode ? backgroundDark : Colors.white;
    Color dividerColor = isDarkMode ? Colors.grey[700]! : pinkLighter;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: pinkLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 25),

          _buildMenuItem(
            icon: Icons.add_location_alt,
            title: 'Guardar nuevo recuerdo',
            color: pinkAccent,
            onTap: () {
              Navigator.pop(context);
              widget.onCreateNewMemory();
            },
            isDarkMode: isDarkMode,
          ),

          Divider(color: dividerColor),

          _buildMenuItem(
            icon: Icons.zoom_out_map,
            title: 'Centrar en todos los recuerdos',
            color: pinkPrimary,
            onTap: widget.onShowAllMemories,
            isDarkMode: isDarkMode,
          ),

          _buildMenuItem(
            icon: Icons.filter_center_focus,
            title: 'Centrar favoritos',
            color: pinkPrimary,
            onTap: () {
              Navigator.pop(context);
              final favs = widget.memories.where((m) => m.isFavorite).toList();
              if (favs.isNotEmpty) widget.onCenterList(favs);
            },
            isDarkMode: isDarkMode,
          ),

          _buildMenuItem(
            icon: Icons.list,
            title: 'Listar todos los recuerdos',
            color: pinkPrimary,
            onTap: () {
              Navigator.pop(context);
              _showMemoryListModal(
                  widget.memories, 'Todos los Recuerdos', theme, isDarkMode);
            },
            isDarkMode: isDarkMode,
          ),

          _buildMenuItem(
            icon: Icons.favorite,
            title: 'Listar favoritos',
            color: pinkPrimary,
            onTap: () {
              Navigator.pop(context);
              final favs = widget.memories.where((m) => m.isFavorite).toList();
              _showMemoryListModal(favs, 'Mis Favoritos', theme, isDarkMode);
            },
            isDarkMode: isDarkMode,
          ),

          _buildMenuItem(
            icon: Icons.date_range,
            title: 'Listar por fecha (Recientes)',
            color: pinkPrimary,
            onTap: () => _showSortedByDate(theme, isDarkMode),
            isDarkMode: isDarkMode,
          ),

          Divider(color: dividerColor),

          _buildMenuItem(
            icon: Icons.picture_as_pdf,
            title: 'Generar PDF de recuerdos',
            color: Colors.pink,
            onTap: () {
              Navigator.pop(context); // Cerramos el menú
              widget.onGenerarPdf(); 
            },
            isDarkMode: isDarkMode,
          ),

          Divider(color: dividerColor),

          _buildMenuItem(
            icon: Icons.delete_sweep,
            title: 'Eliminar todos los recuerdos',
            color: Colors.pink,
            onTap: widget.onClearAllMemories,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
    required bool isDarkMode,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: color),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      tileColor: isDarkMode ? cardDark.withOpacity(0.3) : null,
    );
  }
}