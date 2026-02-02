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

  void _showMemoryListModal(BuildContext context, List<Memory> list, String title) {
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
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: pinkPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(child: Text('No se encontraron recuerdos.'))
                        : ListView.builder(
                      controller: scrollController,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final memory = list[index];
                        return ListTile(
                          leading: const Icon(Icons.location_pin, color: pinkPrimary),
                          title: Text(memory.title),
                          subtitle: Text(
                            '${memory.date} | ${memory.location['latitude']?.toStringAsFixed(4)}, ${memory.location['longitude']?.toStringAsFixed(4)}',
                          ),
                          onTap: () {
                            // Cierra el modal de la lista y llama al callback de MapScreen
                            Navigator.pop(context);
                            onShowMemoryDetails(memory);
                          },
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
  void _showSortedByDate(BuildContext context) {
    Navigator.pop(context);
    final sortedMemories = List<Memory>.from(memories)
      ..sort((a, b) => b.date.compareTo(a.date)); // Del más reciente al más antiguo
    _showMemoryListModal(context, sortedMemories, 'Recuerdos por Fecha (Recientes)');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
          ),

          const Divider(color: pinkLighter),

          // centramos el mapa en todos los recuerdos
          _buildMenuItem(
            icon: Icons.zoom_out_map,
            title: 'Centrar en todos los recuerdos',
            color: pinkPrimary,
            onTap: onShowAllMemories,
          ),

          _buildMenuItem(
            icon: Icons.list,
            title: 'Listar todos los recuerdos',
            color: pinkPrimary,
            onTap: () {
              Navigator.pop(context);
              _showMemoryListModal(context, memories, 'Todos los Recuerdos');
            },
          ),

          _buildMenuItem(
            icon: Icons.date_range,
            title: 'Listar por fecha (Recientes)',
            color: pinkPrimary,
            onTap: () => _showSortedByDate(context),
          ),

          const Divider(color: pinkLighter),

          // eliminamos todos los recuerdos
          _buildMenuItem(
            icon: Icons.delete_sweep,
            title: 'Eliminar todos los recuerdos',
            color: Colors.pink,
            onTap: onClearAllMemories,
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
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: color),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }
}