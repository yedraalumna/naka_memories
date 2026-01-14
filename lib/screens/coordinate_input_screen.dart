import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/colors.dart';
import '../models/Memory.dart';
import 'map_screen.dart';

// Esta pantalla se encarga de que el usuario elija una coordenada
class CoordinateInputScreen extends StatefulWidget {
  final Memory? existingMemory;

  const CoordinateInputScreen({
    super.key,
    this.existingMemory,
  });

  @override
  State<CoordinateInputScreen> createState() => _CoordinateInputScreenState();
}

class _CoordinateInputScreenState extends State<CoordinateInputScreen> {
  // Es la coordenada que se actualizará al mover el mapa
  LatLng _selectedPosition = const LatLng(40.4168, -3.7038); // Posición inicial (Madrid)

  @override
  void initState() {
    super.initState();
    // Si se está editando una memoria existente, usa su ubicación como posición inicial
    if (widget.existingMemory != null) {
      _selectedPosition = widget.existingMemory!.toLatLng;
    }
  }

  void _saveSelectedCoordinate() {
    // Si estamos editando una memoria existente, crea una copia actualizada con la nueva ubicación
    if (widget.existingMemory != null) {
      final updatedMemory = Memory(
        id: widget.existingMemory!.id,
        title: widget.existingMemory!.title,
        description: widget.existingMemory!.description,
        date: widget.existingMemory!.date,
        location: {
          'latitude': _selectedPosition.latitude,
          'longitude': _selectedPosition.longitude,
        },
        imageAsset: widget.existingMemory!.imageAsset,
      );
      Navigator.pop(context, updatedMemory); // Devuelve la memoria actualizada
    } else {
      // Si es una nueva memoria, solo devuelve la ubicación seleccionada
      Navigator.pop(context, _selectedPosition);
    }
  }

  // Función para cerrar la pantalla sin seleccionar coordenadas
  void _cancelSelection() {
    // Retorna null (o nada) para indicar que se canceló la operación
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingMemory != null
              ? 'Editar ubicación del recuerdo'
              : 'Seleccionar coordenadas',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: pinkPrimary,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _cancelSelection,
        ),
      ),
      body: Stack(
        children: [
          MapScreen(
            isLibrary: false,
            initialMarkers: widget.existingMemory != null
                ? {
              Marker(
                markerId: const MarkerId('existing_memory'),
                position: _selectedPosition, // Muestra el marcador en la ubicación existente
              ),
            }
                : const {}, // Sin marcadores si es una nueva memoria
            onMapCreatedCallback: (controller) {
              // Si hay una memoria existente, centra el mapa en su ubicación
              if (widget.existingMemory != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _selectedPosition,
                      zoom: 15, // Nivel de zoom adecuado para ver la ubicación
                    ),
                  ),
                );
              }
            },
            onCameraMoveCallback: (position) {
              // Actualiza la posición central del mapa mientras el usuario se mueve
              setState(() {
                _selectedPosition = position;
              });
            },
            // Desactivamos el LongPress en esta pantalla
            onLongPressCallback: (position, controller) {},
          ),

          // 2. Icono central para indicar la selección (el punto de mira y se mantiene fijo en el centro de la vista)
          const Center(
            child: Icon(Icons.add_location_alt, color: pinkAccent, size: 45),
          ),

          // Panel de coordenadas
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: SafeArea(
              child: Card(
                color: Colors.white,
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Muestra las coordenadas actuales
                      Text(
                        'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}, Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: pinkDark, fontWeight: FontWeight.w600),
                      ),
                      // Si estamos editando, muestra el título del recuerdo
                      if (widget.existingMemory != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Editando: ${widget.existingMemory!.title}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Botón para confirmar y guardar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSelectedCoordinate,
        label: Text(
          widget.existingMemory != null
              ? 'Actualizar Ubicación'
              : 'Marcar y Continuar',
          style: const TextStyle(color: Colors.white),
        ),
        icon: Icon(
          widget.existingMemory != null
              ? Icons.save // Icono de guardar para edición
              : Icons.navigate_next, // Icono de continuar para nueva memoria
          color: Colors.white,
        ),
        backgroundColor: pinkPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}