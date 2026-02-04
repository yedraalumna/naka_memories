import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
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
  bool _isWeb = kIsWeb;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Si se está editando una memoria existente, usa su ubicación como posición inicial
    if (widget.existingMemory != null) {
      _selectedPosition = widget.existingMemory!.toLatLng;
      _markers = {
        Marker(
          markerId: const MarkerId('existing_memory'),
          position: _selectedPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        ),
      };
    }
  }

  // Para web: crear un mapa simple con flutter_map
  Widget _buildWebMap() {
    // En web, usaremos un enfoque simplificado
    // Para un mapa interactivo completo en web, necesitarías configurar flutter_map correctamente
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 100, color: pinkPrimary),
          const SizedBox(height: 20),
          const Text(
            'Para seleccionar coordenadas en el mapa:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Usa la aplicación en tu dispositivo móvil para seleccionar directamente en el mapa.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    'O ingresa las coordenadas manualmente:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Latitud',
                            prefixIcon: const Icon(Icons.north, color: pinkPrimary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            final lat = double.tryParse(value);
                            if (lat != null) {
                              setState(() {
                                _selectedPosition = LatLng(lat, _selectedPosition.longitude);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Longitud',
                            prefixIcon: const Icon(Icons.east, color: pinkPrimary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            final lng = double.tryParse(value);
                            if (lng != null) {
                              setState(() {
                                _selectedPosition = LatLng(_selectedPosition.latitude, lng);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Para móvil: usar el mapa interactivo
  Widget _buildMobileMap() {
    return Stack(
      children: [
        MapScreen(
          isLibrary: false,
          initialMarkers: _markers,
          onMapCreatedCallback: (controller) {
            if (widget.existingMemory != null) {
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _selectedPosition,
                    zoom: 15,
                  ),
                ),
              );
            }
          },
          onCameraMoveCallback: (position) {
            // Actualiza la posición central del mapa mientras el usuario se mueve
            setState(() {
              _selectedPosition = position;
              // Actualizar marcador si existe
              if (_markers.isNotEmpty) {
                _markers = {
                  Marker(
                    markerId: const MarkerId('existing_memory'),
                    position: position,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRose),
                  ),
                };
              }
            });
          },
          onLongPressCallback: (position, controller) {
            // Cuando el usuario hace long press, mover el mapa a esa posición
            controller.animateCamera(CameraUpdate.newLatLng(position));
            setState(() {
              _selectedPosition = position;
              _markers = {
                Marker(
                  markerId: const MarkerId('selected_position'),
                  position: position,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRose),
                ),
              };
            });
          },
        ),

        // Icono central para indicar la selección
        const Center(
          child: Icon(
            Icons.add_location_alt,
            color: pinkAccent,
            size: 45,
          ),
        ),
      ],
    );
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
          // Mapa (web o móvil)
          _isWeb ? _buildWebMap() : _buildMobileMap(),

          // Panel de coordenadas (siempre visible)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: SafeArea(
              child: Card(
                color: Colors.white,
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Muestra las coordenadas actuales
                      Text(
                        'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: pinkDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: pinkDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Si estamos editando, muestra el título del recuerdo
                      if (widget.existingMemory != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Editando: ${widget.existingMemory!.title}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Indicador de plataforma
                      if (_isWeb)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Modo web - Ingresa coordenadas manualmente',
                            style: TextStyle(
                              fontSize: 11,
                              color: pinkPrimary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Instrucciones para móvil
          if (!_isWeb)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.black.withOpacity(0.7),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cómo seleccionar:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '1. Mueve el mapa para ajustar la ubicación',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const Text(
                        '2. Las coordenadas se actualizan automáticamente',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const Text(
                        '3. Toca y mantén presionado para mover directamente',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Botón para confirmar y guardar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          onPressed: _saveSelectedCoordinate,
          label: Text(
            widget.existingMemory != null
                ? 'Actualizar Ubicación'
                : 'Confirmar ubicación',
            style: const TextStyle(color: Colors.white),
          ),
          icon: Icon(
            widget.existingMemory != null ? Icons.save : Icons.check,
            color: Colors.white,
          ),
          backgroundColor: pinkPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}