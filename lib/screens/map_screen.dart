import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:url_launcher/url_launcher.dart';

import '../widget/MemoryForm.dart';
import '../widget/MemoryDetailScreen.dart';
import '../widget/menu_dialog.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import '../constants/map_style.dart';
import '../screens/coordinate_input_screen.dart';

class MapScreen extends StatefulWidget {
  final bool isLibrary;
  final Set<Marker>? initialMarkers;
  final Function(GoogleMapController)? onMapCreatedCallback;
  final Function(LatLng)? onCameraMoveCallback;
  final Function(LatLng, GoogleMapController)? onLongPressCallback;

  MapScreen({
    this.isLibrary = true,
    this.initialMarkers,
    this.onMapCreatedCallback,
    this.onCameraMoveCallback,
    this.onLongPressCallback,
  });

  @override
  State<MapScreen> createState() {
    return _MapScreenState();
  }
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng _currentCameraPosition = LatLng(40.4168, -3.7038);
  Set<Marker> _markers = {};
  final List<Memory> _memories = [];
  final MemoryService _memoryService = MemoryService();

  // Método para detectar si es web
  bool get _isWeb {
    return identical(0, 0.0);
  }

  @override
  void initState() {
    super.initState();

    if (widget.isLibrary) {
      _loadMemories();
    } else if (widget.initialMarkers != null) {
      _markers = widget.initialMarkers!;
    }
  }

  Future<void> _loadMemories() async {
    try {
      final memories = await _memoryService.getMemories();
      setState(() {
        _memories.clear();
        _memories.addAll(memories);
        _addMarkers(memories);
      });
    } catch (e) {
      _showErrorDialog('Error al cargar recuerdos: $e');
    }
  }

  void _addMarkers(List<Memory> memories) {
    setState(() {
      _markers = memories.map((memory) {
        return Marker(
          markerId: MarkerId(memory.id),
          position: memory.toLatLng,
          infoWindow: InfoWindow(
            title: memory.title,
            snippet: memory.description,
            onTap: () {
              _showMemoryDetails(memory);
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          onTap: () {
            _showMemoryDetails(memory);
          },
        );
      }).toSet();
    });
  }

  void _handleSaveCoordinatesFromMenu() {
    Navigator.pop(context);
    _navigateToCoordinateInput();
  }

  void _goToCoordinates() {
    if (_memories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay recuerdos guardados para mostrar.'),
          backgroundColor: pinkPrimary,
        ),
      );
      return;
    }

    final firstPosition = _memories.first.toLatLng;
    if (_isWeb) {
      Navigator.pop(context);
    } else {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: firstPosition, zoom: 15),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _navigateToCoordinateInput() async {
    final LatLng? selectedLocation = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (context) {
          return CoordinateInputScreen();
        },
      ),
    );

    if (selectedLocation != null) {
      _showMemoryForm(selectedLocation);
    } else {
      _loadMemories();
    }
  }

  void _showMenuDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MenuDialog(
          memories: _memories,
          currentPosition: _currentCameraPosition,
          onShowAllMemories: _goToCoordinates,
          onSaveCurrentCoordinates: _handleSaveCoordinatesFromMenu,
          onClearAllMemories: _confirmClearAllMemories,
          onShowMemoryDetails: _showMemoryDetails,
        );
      },
    );
  }

  void _onMapLongPress(LatLng position) {
    if (!_isWeb) {
      mapController.animateCamera(CameraUpdate.newLatLng(position));
    }
    _showMemoryForm(position);
  }

  void _showMemoryForm(LatLng location, {Memory? existingMemory}) {
    showDialog(
      context: context,
      builder: (context) {
        return MemoryForm(
          location: location,
          existingMemory: existingMemory,
          onSave: (memory) async {
            await _memoryService.saveMemory(memory);
            Navigator.of(context).pop();
            _loadMemories();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  // NUEVO MÉTODO: Editar solo la ubicación (similar a MemoryGalleryScreen)
  Future<void> _editOnlyLocation(Memory memory) async {
    // Cerrar el modal de detalles primero
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Navegar a CoordinateInputScreen con la memoria existente
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoordinateInputScreen(
          existingMemory: memory,
        ),
      ),
    );

    // Procesar el resultado
    if (result != null && result is Memory) {
      await _memoryService.saveMemory(result);
      _loadMemories(); // Recargar los datos

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ubicación actualizada correctamente'),
          backgroundColor: pinkPrimary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // MÉTODO ACTUALIZADO: Ahora separa editar todo de editar solo ubicación
  void _showMemoryDetails(Memory memory) {
    // Cerrar el menú dialog si está abierto
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MemoryDetailScreen(
          memory: memory,
          onEdit: () {
            // Ahora llama al método para editar solo ubicación
            _editOnlyLocation(memory);
          },
          onDelete: () async {
            try {
              // Cerrar el modal de detalles
              Navigator.of(context).pop();
              // Eliminar la memoria
              await _memoryService.deleteMemory(memory.id);
              // Recargar los datos
              _loadMemories();
              // Mostrar confirmación
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${memory.title} eliminado.'),
                  backgroundColor: pinkPrimary,
                ),
              );
            } catch (e) {
              // Mostrar error si falla
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al eliminar: $e'),
                  backgroundColor: Colors.pinkAccent,
                ),
              );
            }
          },
          // NUEVO: callback para actualizar la memoria cuando se edita todo
          onUpdate: (updatedMemory) async {
            await _memoryService.saveMemory(updatedMemory);
            _loadMemories(); // Recargar los datos

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Recuerdo actualizado correctamente'),
                backgroundColor: pinkPrimary,
                duration: Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmClearAllMemories() async {
    Navigator.pop(context);

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de eliminar todos los recuerdos? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _memoryService.clearAllMemories();
      await _loadMemories();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.white),
              SizedBox(width: 10),
              Text('Todos los recuerdos eliminados'),
            ],
          ),
          backgroundColor: pinkPrimary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // MÉTODO PARA EL MAPA WEB - VERSIÓN SIMPLIFICADA
  Widget _buildWebMap({bool forLibrary = true}) {
    return fmap.FlutterMap(
      options: fmap.MapOptions(
        initialCenter: latlong2.LatLng(40.4168, -3.7038), // CORREGIDO: initialCenter en lugar de center
        initialZoom: 15.0,
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.mi_prueba',
        ),
        fmap.RichAttributionWidget(
          attributions: [
            fmap.TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(
                  Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // SI ES WEB, USAR FLUTTER MAP
    if (_isWeb) {
      if (!widget.isLibrary) {
        return _buildWebMap(forLibrary: false);
      }

      return Scaffold(
        appBar: AppBar(
          title: Text('Memory Places', style: TextStyle(color: pinkDark, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 1,
          actions: [
            IconButton(
              icon: Icon(Icons.menu, color: pinkPrimary),
              onPressed: _showMenuDialog,
            ),
          ],
        ),
        body: _buildWebMap(forLibrary: true),
      );
    }

    // SI ES MÓVIL, USAR GOOGLE MAPS ORIGINAL
    if (!widget.isLibrary) {
      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(40.4168, -3.7038),
          zoom: 15,
        ),
        onMapCreated: (controller) {
          mapController = controller;
          mapController.setMapStyle(mapStyle);
          if (widget.onMapCreatedCallback != null) {
            widget.onMapCreatedCallback!(controller);
          }
        },
        onCameraMove: (position) {
          if (widget.onCameraMoveCallback != null) {
            widget.onCameraMoveCallback!(position.target);
          }
        },
        markers: widget.initialMarkers ?? {},
        onLongPress: (position) {
          if (widget.onLongPressCallback != null) {
            widget.onLongPressCallback!(position, mapController);
          }
        },
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Memory Places', style: TextStyle(color: pinkDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: pinkPrimary),
            onPressed: _showMenuDialog,
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(40.4168, -3.7038),
          zoom: 15,
        ),
        onMapCreated: (controller) {
          mapController = controller;
          mapController.setMapStyle(mapStyle);
          _loadMemories();
        },
        onCameraMove: (position) {
          _currentCameraPosition = position.target;
        },
        markers: _markers,
        onLongPress: _onMapLongPress,
        zoomControlsEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}