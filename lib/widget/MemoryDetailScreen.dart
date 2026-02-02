import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import 'MemoryForm.dart';
import 'dart:io'; //Obligatorio para leer archivos locales (la camara y la galeria)
import 'package:flutter/foundation.dart';

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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: pinkPrimary.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                _buildHeader(context),
                _buildContent(context),
              ],
            ),
          ),
        );
      },
    );
  }

  //Construimos el encabezado superior con fondo degradado
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [pinkPrimary, pinkAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImage(),
          const SizedBox(height: 25),
          _buildTitle(),
          const SizedBox(height: 15),
          _buildDate(),
          const SizedBox(height: 20),
          _buildDescription(),
          const SizedBox(height: 25),
          _buildLocationInfo(),
          const SizedBox(height: 30),
          _buildActionButtons(context),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Construimos la sección de imagen soportando archivos locales
  Widget _buildImage() {
    if (memory.imageAsset != null && memory.imageAsset!.isNotEmpty) {
      Widget imageWidget;

      if (memory.imageAsset!.startsWith('assets/')) {
        imageWidget = Image.asset(
          memory.imageAsset!,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorContainer(),
        );
      }
      // WEB
      else if (kIsWeb) {
        imageWidget = Image.network(
          memory.imageAsset!,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorContainer(),
        );
      }
      // MÓVIL
      else {
        imageWidget = Image.file(
          File(memory.imageAsset!),
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorContainer(),
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
        color: pinkLighter,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight, style: BorderStyle.solid),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 50, color: pinkPrimary),
            SizedBox(height: 10),
            Text(
              'Sin imagen',
              style: TextStyle(color: pinkDark),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para control de errores de carga de imagen
  Widget _buildErrorContainer() {
    return Container(
      height: 250,
      color: pinkLighter,
      alignment: Alignment.center,
      child: const Icon(Icons.error, color: pinkDark, size: 50),
    );
  }

  //Muestra el título principal de la memoria
  Widget _buildTitle() {
    return Text(
      memory.title,
      style: const TextStyle(
        color: pinkDark,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
    );
  }

  // mostramos la fecha del recuerdo con icono de calendario
  Widget _buildDate() {
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: pinkPrimary, size: 18),
        const SizedBox(width: 8),
        Text(
          memory.date,
          style: TextStyle(
            color: pinkDark.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // mostramos la descripción detallada del recuerdo
  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descripción',
          style: TextStyle(
            color: pinkDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          memory.description,
          style: const TextStyle(
            color: backgroundDark,
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // mostramos la información de ubicación, es decir las coordenadas
  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [pinkLighter, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: pinkPrimary, size: 24),
              SizedBox(width: 10),
              Text(
                'Ubicación Exacta',
                style: TextStyle(
                  color: pinkDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.north, color: pinkPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Latitud: ${memory.latitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: pinkDark,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.east, color: pinkPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Longitud: ${memory.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: pinkDark,
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
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _showEditOptions(context);
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
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: pinkPrimary, width: 2),
              ),
            ),
            icon: const Icon(Icons.delete, color: pinkPrimary),
            label: const Text(
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
  void _showEditOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título del menú de opciones
              const Text(
                '¿Qué deseas editar?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: pinkDark,
                ),
              ),

              const SizedBox(height: 20),

              // Opción 1: Editar solo la ubicación (coordenadas)
              ListTile(
                leading: const Icon(Icons.edit_location, color: pinkPrimary),
                title: const Text('Editar solo ubicación'),
                subtitle: const Text('Cambia las coordenadas del recuerdo'),
                onTap: () {
                  Navigator.pop(context); // Cierra el menú de opciones
                  onEdit(); // Ejecuta la función de edición
                },
              ),

              const Divider(),

              // Opción 2: Editar todos los datos (título, descripción, fecha, imagen)
              ListTile(
                leading: const Icon(Icons.edit_note, color: pinkPrimary),
                title: const Text('Editar todos los datos'),
                subtitle: const Text(
                    'Título, descripción, fecha, imagen y ubicación'),
                onTap: () {
                  Navigator.pop(context); // Cierra el menú de opciones
                  _navigateToFullEditForm(context);
                },
              ),

              const Divider(),

              // Eliminar recuerdo
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.pinkAccent),
                title: const Text('Eliminar recuerdo'),
                subtitle: const Text('Elimina permanentemente este recuerdo'),
                onTap: () {
                  Navigator.pop(context); // Cierra el menú de opciones
                  // Llama directamente a la función onDelete
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
            // Cierra el diálogo del formulario
            Navigator.pop(context);

            // Cierra también el modal de detalles si está abierto
            Navigator.pop(context);

            if (onUpdate != null) {
              onUpdate!(updatedMemory);
            }

            // Muestra el mensaje de confirmación
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recuerdo actualizado correctamente'),
                backgroundColor: pinkPrimary,
                duration: Duration(seconds: 2),
              ),
            );
          },
          onCancel: () {
            Navigator.pop(context); // Cerrar el diálogo
          },
        );
      },
    );
  }
}
