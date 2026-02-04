import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';

class MenuDialog extends StatelessWidget {
  final List<Memory> memories;
  final LatLng currentPosition;

  final VoidCallback onShowAllMemories;
  final VoidCallback onSaveCurrentCoordinates;
  final VoidCallback onClearAllMemories;
  final Function(Memory) onShowMemoryDetails;

  const MenuDialog({
    super.key,
    required this.memories,
    required this.currentPosition,
    required this.onShowAllMemories,
    required this.onSaveCurrentCoordinates,
    required this.onClearAllMemories,
    required this.onShowMemoryDetails,
  });

  void _showMemoryListModal(BuildContext context, List<Memory> list, String title, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            Color backgroundColor = theme.brightness == Brightness.dark ? backgroundDark : Colors.white;
            Color textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black;
            Color primaryColor = theme.brightness == Brightness.dark ? pinkLight : pinkPrimary;
            
            return Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                      itemBuilder: (context, index) {
                        final memory = list[index];
                        return ListTile(
                          leading: Icon(Icons.location_pin, color: primaryColor),
                          title: Text(
                            memory.title,
                            style: TextStyle(color: textColor),
                          ),
                          subtitle: Text(
                            '${memory.date} | ${memory.location['latitude']?.toStringAsFixed(4)}, ${memory.location['longitude']?.toStringAsFixed(4)}',
                            style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]),
                          ),
                          onTap: () {
                            // Cierra el modal de la lista y llama al callback de MapScreen
                            Navigator.pop(context);
                            onShowMemoryDetails(memory);
                          },
                          tileColor: theme.brightness == Brightness.dark ? cardDark.withOpacity(0.5) : null,
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

  // ordenamos por fecha de la mas reciente a la mas antigua
  void _showSortedByDate(BuildContext context, ThemeData theme) {
    Navigator.pop(context);
    final sortedMemories = List<Memory>.from(memories)
      ..sort((a, b) => b.date.compareTo(a.date)); // Del más reciente al más antiguo
    _showMemoryListModal(context, sortedMemories, 'Recuerdos por Fecha (Recientes)', theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool isDarkMode = theme.brightness == Brightness.dark;
    
    Color backgroundColor = isDarkMode ? backgroundDark : Colors.white;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;
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

          // Guardamos un nuevo recuerdo
          _buildMenuItem(
            icon: Icons.add_location_alt,
            title: 'Guardar nuevo recuerdo (Elegir coordenadas)',
            color: pinkAccent,
            onTap: onSaveCurrentCoordinates,
            isDarkMode: isDarkMode,
          ),

          Divider(color: dividerColor),

          // centramos el mapa en todos los recuerdos
          _buildMenuItem(
            icon: Icons.zoom_out_map,
            title: 'Centrar en todos los recuerdos',
            color: pinkPrimary,
            onTap: onShowAllMemories,
            isDarkMode: isDarkMode,
          ),

          _buildMenuItem(
            icon: Icons.list,
            title: 'Listar todos los recuerdos',
            color: pinkPrimary,
            onTap: () {
              Navigator.pop(context);
              _showMemoryListModal(context, memories, 'Todos los Recuerdos', theme);
            },
            isDarkMode: isDarkMode,
          ),

          _buildMenuItem(
            icon: Icons.date_range,
            title: 'Listar por fecha (Recientes)',
            color: pinkPrimary,
            onTap: () => _showSortedByDate(context, theme),
            isDarkMode: isDarkMode,
          ),

          Divider(color: dividerColor),

          // eliminamos todos los recuerdos
          _buildMenuItem(
            icon: Icons.delete_sweep,
            title: 'Eliminar todos los recuerdos',
            color: Colors.pink,
            onTap: onClearAllMemories,
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