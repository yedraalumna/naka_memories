import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import 'MemoryForm.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class MemoryDetailScreen extends StatelessWidget {
  final Memory memory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(Memory)? onUpdate;

  const MemoryDetailScreen({
    super.key,
    required this.memory,
    required this.onEdit,
    required this.onDelete,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? backgroundDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: pinkPrimary.withOpacity(isDarkMode ? 0.1 : 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                _buildHeader(context, isDarkMode),
                _buildContent(context, isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  //Construimos el encabezado superior
  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: isDarkMode ? pinkDark : pinkPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalles del Recuerdo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Un lugar especial para ti',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Contenedor principal con todos los elementos de la memoria
  Widget _buildContent(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImage(isDarkMode),
          const SizedBox(height: 25),
          _buildTitle(isDarkMode),
          const SizedBox(height: 15),
          _buildDate(isDarkMode),
          const SizedBox(height: 20),
          _buildDescription(isDarkMode),
          const SizedBox(height: 25),
          _buildLocationInfo(isDarkMode),
          const SizedBox(height: 30),
          _buildActionButtons(context, isDarkMode),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Construimos la sección de imagen soportando archivos locales
  Widget _buildImage(bool isDarkMode) {
    if (memory.imageAsset != null && memory.imageAsset!.isNotEmpty) {
      Widget imageWidget;

      if (memory.imageAsset!.startsWith('assets/')) {
        imageWidget = Image.asset(
          memory.imageAsset!,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorContainer(isDarkMode),
        );
      }
      // WEB
      else if (kIsWeb) {
        imageWidget = Image.network(
          memory.imageAsset!,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorContainer(isDarkMode),
        );
      }
      // MÓVIL
      else {
        imageWidget = Image.file(
          File(memory.imageAsset!),
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorContainer(isDarkMode),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: imageWidget,
      );
    }

    // Placeholder por defecto si no hay imagen
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: isDarkMode ? cardDark : pinkLighter,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : pinkLight, 
          style: BorderStyle.solid
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 50, color: pinkPrimary),
            const SizedBox(height: 10),
            Text(
              'Sin imagen',
              style: TextStyle(color: pinkPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para control de errores de carga de imagen
  Widget _buildErrorContainer(bool isDarkMode) {
    return Container(
      height: 250,
      color: isDarkMode ? cardDark : pinkLighter,
      alignment: Alignment.center,
      child: Icon(Icons.error, color: pinkPrimary, size: 50),
    );
  }

  //Muestra el título principal de la memoria
  Widget _buildTitle(bool isDarkMode) {
    return Text(
      memory.title,
      style: TextStyle(
        color: isDarkMode ? textDarkMode : pinkDark,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
    );
  }

  // mostramos la fecha del recuerdo con icono de calendario
  Widget _buildDate(bool isDarkMode) {
    return Row(
      children: [
        Icon(Icons.calendar_today, color: pinkPrimary, size: 18),
        const SizedBox(width: 8),
        Text(
          memory.date,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : pinkDark.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // mostramos la descripción detallada del recuerdo
  Widget _buildDescription(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Descripción',
          style: TextStyle(
            color: isDarkMode ? textDarkMode : pinkDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          memory.description,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : backgroundDark,
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // mostramos la información de ubicación, es decir las coordenadas
  Widget _buildLocationInfo(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? cardDark : pinkLighter,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : pinkLight.withOpacity(0.3)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: pinkPrimary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Ubicación Exacta',
                style: TextStyle(
                  color: isDarkMode ? textDarkMode : pinkDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(Icons.north, color: pinkPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Latitud: ${memory.latitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : pinkDark,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.east, color: pinkPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Longitud: ${memory.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : pinkDark,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // construimos los botones de acción, es decir editar y eliminar
  Widget _buildActionButtons(BuildContext context, bool isDarkMode) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _showEditOptions(context, isDarkMode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: pinkPrimary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
            ),
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              'Editar Recuerdo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 15),

        // Botón de Eliminar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? cardDark : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: pinkPrimary, width: 2),
              ),
            ),
            icon: Icon(Icons.delete, color: pinkPrimary),
            label: Text(
              'Eliminar',
              style: TextStyle(
                color: pinkPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Mostrar un menú con opciones de edición
  void _showEditOptions(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? backgroundDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título del menú de opciones
              Text(
                '¿Qué deseas editar?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? textDarkMode : pinkDark,
                ),
              ),

              const SizedBox(height: 20),

              // Opción 1: Editar solo la ubicación (coordenadas)
              ListTile(
                leading: Icon(Icons.edit_location, color: pinkPrimary),
                title: Text(
                  'Editar solo ubicación',
                  style: TextStyle(
                    color: isDarkMode ? textDarkMode : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Cambia las coordenadas del recuerdo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                tileColor: isDarkMode ? cardDark.withOpacity(0.5) : null,
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),

              Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),

              // Opción 2: Editar todos los datos
              ListTile(
                leading: Icon(Icons.edit_note, color: pinkPrimary),
                title: Text(
                  'Editar todos los datos',
                  style: TextStyle(
                    color: isDarkMode ? textDarkMode : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Título, descripción, fecha, imagen y ubicación',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                tileColor: isDarkMode ? cardDark.withOpacity(0.5) : null,
                onTap: () {
                  Navigator.pop(context);
                  _navigateToFullEditForm(context);
                },
              ),

              Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),

              // Eliminar recuerdo
              ListTile(
                leading: Icon(Icons.delete, color: Colors.pinkAccent),
                title: Text(
                  'Eliminar recuerdo',
                  style: TextStyle(
                    color: isDarkMode ? textDarkMode : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Elimina permanentemente este recuerdo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                tileColor: isDarkMode ? cardDark.withOpacity(0.5) : null,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToFullEditForm(BuildContext context) {
    // Muestra el formulario de edición completa
    showDialog(
      context: context,
      builder: (context) {
        return MemoryForm(
          location: LatLng(memory.latitude, memory.longitude),
          existingMemory: memory,
          onSave: (updatedMemory) {
            Navigator.pop(context);
            Navigator.pop(context);

            if (onUpdate != null) {
              onUpdate!(updatedMemory);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Recuerdo actualizado correctamente'),
                backgroundColor: pinkPrimary,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onCancel: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }
}