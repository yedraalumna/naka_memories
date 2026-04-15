import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import 'MemoryThumbnail.dart';
import '../providers/theme_provider.dart';

/// Menú flotante que aparece al pulsar el botón de menú en el mapa el cual permite crear recuerdos, centrar el mapa, listar recuerdos, generar PDF, etc
class MenuDialog extends StatefulWidget {
  final List<Memory> memories;           // Lista de todos los recuerdos
  final LatLng currentPosition;          // Posición actual del mapa
  final VoidCallback onShowAllMemories;   // Función para centrar el mapa en todos los recuerdos
  final VoidCallback onSaveCurrentCoordinates; // Función para guardar coordenadas actuales
  final VoidCallback onCreateNewMemory;   // Función para crear un nuevo recuerdo
  final VoidCallback onClearAllMemories;  // Función para eliminar todos los recuerdos
  final Function(Memory) onShowMemoryDetails; // Función para mostrar detalles de un recuerdo
  final Function(List<Memory>) onCenterList;  // Función para centrar el mapa en una lista
  final VoidCallback onGenerarPdf;        // Función para generar PDF

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
  State<MenuDialog> createState() {
    return _MenuDialogState();
  }
}

class _MenuDialogState extends State<MenuDialog> {

  /// Muestra un modal con una lista de recuerdos como todos, favoritos y por fecha
  void _showMemoryListModal(List<Memory> list, String title, ThemeData theme, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,      
      backgroundColor: Colors.transparent,  
      builder: (contextModal) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,     
          maxChildSize: 0.95,        
          minChildSize: 0.5,        
          builder: (contextSheet, scrollController) {
            
            // Colores según el tema
            Color colorFondo;
            Color colorTexto;
            Color colorPrincipal;
            
            if (isDarkMode == true) {
              colorFondo = backgroundDark;
              colorTexto = Colors.white;
              colorPrincipal = pinkLight;
            } else {
              colorFondo = Colors.white;
              colorTexto = Colors.black;
              colorPrincipal = pinkPrimary;
            }

            return Container(
              decoration: BoxDecoration(
                color: colorFondo,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Título del modal
                  Container(
                    padding: const EdgeInsets.all(15),
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorPrincipal,
                      ),
                    ),
                  ),
                  Expanded(
                    // Si la lista está vacía, mostramos un el mensaje
                    child: () {
                      if (list.isEmpty == true) {
                        return Center(
                          child: Text('No se encontraron recuerdos.',
                            style: TextStyle(color: colorTexto),
                          ),
                        );
                      } else {
                        // Si hay recuerdos, lo mostramos en una lista
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: list.length,
                          itemBuilder: (contextItem, index) {
                            final memory = list[index];
                            
                            // Color del fondo de cada elemento de la lista
                            Color? colorTile;
                            if (theme.brightness == Brightness.dark) {
                              colorTile = cardDark.withOpacity(0.5);
                            } else {
                              colorTile = null;
                            }
                            
                            return ListTile(
                              leading: MemoryThumbnail(
                                imagePath: memory.imageAsset,
                                width: 50,
                                height: 50,
                              ),
                              title: Text(
                                memory.title,
                                style: TextStyle(color: colorTexto),
                              ),
                              subtitle: () {
                                // Obtenemos la latitud y longitud de forma segura
                                String latitud;
                                String longitud;
                                
                                if (memory.location['latitude'] != null) {
                                  latitud = memory.location['latitude']!.toStringAsFixed(4);
                                } else {
                                  latitud = '0.0000';
                                }
                                
                                if (memory.location['longitude'] != null) {
                                  longitud = memory.location['longitude']!.toStringAsFixed(4);
                                } else {
                                  longitud = '0.0000';
                                }
                                
                                Color colorSubtitulo;
                                if (theme.brightness == Brightness.dark) {
                                  colorSubtitulo = Colors.grey[400]!;
                                } else {
                                  colorSubtitulo = Colors.grey[700]!;
                                }
                                
                                return Text('${memory.date} | $latitud, $longitud',
                                  style: TextStyle(color: colorSubtitulo),
                                );
                              }(),
                              onTap: () {
                                Navigator.pop(contextItem);
                                widget.onShowMemoryDetails(memory);
                              },
                              tileColor: colorTile,
                            );
                          },
                        );
                      }
                    }(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// mostramos los recuerdos ordenados por fecha, del más reciente al más antiguo
  void _showSortedByDate(ThemeData theme, bool isDarkMode) {
    // Cerramos el menú actual
    Navigator.pop(context);
    
    // Creamos una copia de la lista y la ordenamos por fecha descendente
    final List<Memory> sortedMemories = List<Memory>.from(widget.memories);
    sortedMemories.sort((a, b) {
      return b.date.compareTo(a.date);
    });
    
    //Mostramos el modal con la lista ordenada
    _showMemoryListModal(sortedMemories, 'Recuerdos por Fecha (Recientes)', theme, isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    // Determinamos si estamos en modo oscuro
    bool isDarkMode;
    if (themeProvider.themeMode == ThemeMode.system) {
      // Si es automático, miramos la configuración del sistema
      if (MediaQuery.of(context).platformBrightness == Brightness.dark) {
        isDarkMode = true;
      } else {
        isDarkMode = false;
      }
    } else {
      // Si no es automático, miramos la configuración guardada
      if (themeProvider.themeMode == ThemeMode.dark) {
        isDarkMode = true;
      } else {
        isDarkMode = false;
      }
    }

    // Colores según el modo oscuro
    Color colorFondo;
    Color colorDivisor;
    
    if (isDarkMode == true) {
      colorFondo = backgroundDark;
      colorDivisor = Colors.grey[700]!;
    } else {
      colorFondo = Colors.white;
      colorDivisor = pinkLighter;
    }

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: colorFondo,
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

          // guardamos el nuevo recuerdo
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

          Divider(color: colorDivisor),

          // centramos todos los recuerdos
          _buildMenuItem(
            icon: Icons.zoom_out_map,
            title: 'Centrar en todos los recuerdos',
            color: pinkPrimary,
            onTap: widget.onShowAllMemories,
            isDarkMode: isDarkMode,
          ),

          // centramos los recuerdos en favoritos
          _buildMenuItem(
            icon: Icons.filter_center_focus,
            title: 'Centrar favoritos',
            color: pinkPrimary,
            onTap: () {
              Navigator.pop(context);
              final List<Memory> favoritos = [];
              for (var m in widget.memories) {
                if (m.isFavorite == true) {
                  favoritos.add(m);
                }
              }
              if (favoritos.isNotEmpty) {
                widget.onCenterList(favoritos);
              }
            },
            isDarkMode: isDarkMode,
          ),

          // listamos todos los recuerdos
          _buildMenuItem(
            icon: Icons.list,
            title: 'Listar todos los recuerdos',
            color: pinkPrimary,
            onTap: () {
              Navigator.pop(context);
              _showMemoryListModal(widget.memories, 'Todos los Recuerdos', theme, isDarkMode);
            },
            isDarkMode: isDarkMode,
          ),

          // listamos los favoritos
          _buildMenuItem(
            icon: Icons.favorite,
            title: 'Listar favoritos',
            color: pinkPrimary,
            onTap: () {
              Navigator.pop(context);
              final List<Memory> favoritos = [];
              for (var m in widget.memories) {
                if (m.isFavorite == true) {
                  favoritos.add(m);
                }
              }
              _showMemoryListModal(favoritos, 'Mis Favoritos', theme, isDarkMode);
            },
            isDarkMode: isDarkMode,
          ),

          // Opción: Listar por fecha
          _buildMenuItem(
            icon: Icons.date_range,
            title: 'Listar por fecha (Recientes)',
            color: pinkPrimary,
            onTap: () {
              _showSortedByDate(theme, isDarkMode);
            },
            isDarkMode: isDarkMode,
          ),

          Divider(color: colorDivisor),

          // pata generar el PDF
          _buildMenuItem(
            icon: Icons.picture_as_pdf,
            title: 'Generar PDF de recuerdos',
            color: Colors.pink,
            onTap: () {
              Navigator.pop(context);
              widget.onGenerarPdf();
            },
            isDarkMode: isDarkMode,
          ),

          Divider(color: colorDivisor),

          // eliminamos todos los recuerdos
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

  /// Construimos un elemento del menú, icono + texto + flecha
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
    required bool isDarkMode,
  }) {
    // Color de fondo del icono, según modo oscuro 
    Color colorFondoIcono;
    if (isDarkMode == true) {
      colorFondoIcono = color.withOpacity(0.2);
    } else {
      colorFondoIcono = color.withOpacity(0.1);
    }
    
    // Color del texto según modo oscuro)
    Color colorTexto;
    if (isDarkMode == true) {
      colorTexto = Colors.white;
    } else {
      colorTexto = Colors.black87;
    }
    
    // Color de fondo del ListTile (según modo oscuro)
    Color? colorTile;
    if (isDarkMode == true) {
      colorTile = cardDark.withOpacity(0.3);
    } else {
      colorTile = null;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorFondoIcono,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colorTexto,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: color),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      tileColor: colorTile,
    );
  }
}