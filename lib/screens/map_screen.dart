import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:provider/provider.dart';

import '../widget/MemoryForm.dart';
import '../widget/MemoryDetailScreen.dart';
import '../widget/menu_dialog.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import '../constants/map_style.dart';
import '../screens/coordinate_input_screen.dart';
import '../providers/theme_provider.dart';

class MapScreen extends StatefulWidget {
  final bool isLibrary;
  final Set<Marker>? initialMarkers;
  final Function(GoogleMapController)? onMapCreatedCallback;
  final Function(LatLng)? onCameraMoveCallback;
  final Function(LatLng, GoogleMapController)? onLongPressCallback;

  const MapScreen({
    Key? key,
    this.isLibrary = true,
    this.initialMarkers,
    this.onMapCreatedCallback,
    this.onCameraMoveCallback,
    this.onLongPressCallback,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng _currentCameraPosition = const LatLng(40.4168, -3.7038);
  Set<Marker> _markers = {};
  List<Memory> _memories = [];
  final MemoryService _memoryService = MemoryService();
  bool _isLoading = false;

  // Detectar si es web
  bool get _isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    if (widget.isLibrary) {
      _loadMemories();
    } else if (widget.initialMarkers != null) {
      _markers = widget.initialMarkers!;
    }
  }

  // --- MOTOR DE IMÁGENES: CREA MARCADOR CUADRADO CON BORDES REDONDEADOS ---
  Future<BitmapDescriptor> _getMarkerIconSquare(String? path) async {
    const int targetWidth = 80;
    const double borderRadius = 12.0;
    const double borderWidth = 3.0;
    
    try {
      Uint8List bytes;

      if (path == null || path.isEmpty) {
        return await _createDefaultMarkerIconSquare();
      }

      // 1. Obtención de bytes según plataforma y origen
      if (path.startsWith('assets/')) {
        ByteData data = await rootBundle.load(path);
        bytes = data.buffer.asUint8List();
      } else if (_isWeb || path.startsWith('http')) {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode != 200) {
          throw Exception('Failed to load image: ${response.statusCode}');
        }
        bytes = response.bodyBytes;
      } else {
        final file = File(path);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        } else {
          return await _createDefaultMarkerIconSquare();
        }
      }

      // 2. Redimensionar la imagen
      ui.Codec codec = await ui.instantiateImageCodec(
        bytes, 
        targetWidth: targetWidth
      );
      ui.FrameInfo fi = await codec.getNextFrame();
      
      // 3. Crear imagen cuadrada con bordes redondeados
      final pictureRecorder = ui.PictureRecorder();
      final canvas = ui.Canvas(pictureRecorder);
      final paint = ui.Paint();
      
      final rect = ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetWidth.toDouble());
      final innerRect = ui.Rect.fromLTWH(
        borderWidth, 
        borderWidth, 
        targetWidth - (borderWidth * 2), 
        targetWidth - (borderWidth * 2)
      );
      
      // Dibujar fondo con borde rosado
      paint.color = pinkPrimary;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(borderRadius)),
        paint,
      );
      
      // Dibujar fondo interior blanco
      paint.color = Colors.white;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(innerRect, ui.Radius.circular(borderRadius - borderWidth)),
        paint,
      );
      
      // Recortar con bordes redondeados
      final clipPath = ui.Path()
        ..addRRect(ui.RRect.fromRectAndRadius(
          innerRect, 
          ui.Radius.circular(borderRadius - borderWidth)
        ));
      
      canvas.clipPath(clipPath);
      
      // Dibujar la imagen
      canvas.drawImageRect(
        fi.image,
        ui.Rect.fromLTWH(0, 0, fi.image.width.toDouble(), fi.image.height.toDouble()),
        innerRect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      
      // Convertir a bitmap
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(targetWidth, targetWidth);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Failed to convert image to byte data');
      }
      
      return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
      
    } catch (e) {
      debugPrint("Error creando marcador cuadrado: $e");
      return await _createDefaultMarkerIconSquare();
    }
  }

  Future<BitmapDescriptor> _createDefaultMarkerIconSquare() async {
    const double size = 80.0;
    const double borderRadius = 12.0;
    const double borderWidth = 3.0;
    
    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);
    final paint = ui.Paint();
    
    final rect = ui.Rect.fromLTWH(0, 0, size, size);
    final innerRect = ui.Rect.fromLTWH(
      borderWidth, 
      borderWidth, 
      size - (borderWidth * 2), 
      size - (borderWidth * 2)
    );
    
    // Fondo con borde rosado
    paint.color = pinkPrimary;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(borderRadius)),
      paint,
    );
    
    // Fondo interior blanco
    paint.color = Colors.white;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(innerRect, ui.Radius.circular(borderRadius - borderWidth)),
      paint,
    );
    
    // Icono de foto
    final textStyle = ui.TextStyle(
      fontSize: size * 0.4,
      fontFamily: Icons.photo.fontFamily,
      color: pinkPrimary,
    );
    
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..pushStyle(textStyle)
      ..addText(String.fromCharCode(Icons.photo.codePoint));
    
    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: size));
    
    canvas.drawParagraph(
      paragraph,
      ui.Offset(
        size / 2 - paragraph.width / 2,
        size / 2 - paragraph.height / 2,
      ),
    );
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    
    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  // --- CARGA DE RECUERDOS CON MARCADORES PERSONALIZADOS ---
  Future<void> _loadMemories() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final memories = await _memoryService.getMemories();
      Set<Marker> newMarkers = {};

      // Crear marcadores para cada memoria
      for (var memory in memories) {
        try {
          final icon = await _getMarkerIconSquare(memory.imageAsset);
          
          newMarkers.add(
            Marker(
              markerId: MarkerId(memory.id),
              position: memory.toLatLng,
              icon: icon,
              anchor: const Offset(0.5, 0.5), // Centrar el marcador
              infoWindow: InfoWindow(
                title: memory.title,
                snippet: memory.description,
                onTap: () => _showMemoryDetails(memory),
              ),
              onTap: () => _showMemoryDetails(memory),
            ),
          );
        } catch (e) {
          debugPrint("Error creando marcador para ${memory.title}: $e");
          // Usar marcador por defecto si hay error
          newMarkers.add(
            Marker(
              markerId: MarkerId(memory.id),
              position: memory.toLatLng,
              infoWindow: InfoWindow(
                title: memory.title,
                snippet: memory.description,
                onTap: () => _showMemoryDetails(memory),
              ),
              onTap: () => _showMemoryDetails(memory),
            ),
          );
        }
      }

      setState(() {
        _memories = memories;
        _markers = newMarkers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Error al cargar recuerdos: $e');
    }
  }

  // --- MANEJO DE MENÚ Y NAVEGACIÓN ---
  void _handleSaveCoordinatesFromMenu() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    _navigateToCoordinateInput();
  }

  void _goToFirstMemory() {
    if (_memories.isNotEmpty) {
      final firstMemory = _memories.first;
      if (_isWeb) {
        _showSnackbar('Centrado en: ${firstMemory.title}');
        Navigator.pop(context);
      } else {
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(firstMemory.toLatLng, 15),
        );
        Navigator.pop(context);
        _showSnackbar('Centrado en: ${firstMemory.title}');
      }
    } else {
      _showSnackbar('No hay recuerdos guardados', isError: true);
    }
  }

  void _goToAllMemories() {
    if (_memories.length > 1) {
      if (!_isWeb) {
        // Calcular bounds para incluir todos los marcadores
        LatLngBounds bounds = _calculateBounds();
        mapController.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
        Navigator.pop(context);
        _showSnackbar('Mostrando todos los recuerdos (${_memories.length})');
      } else {
        Navigator.pop(context);
        _showSnackbar('Mostrando todos los recuerdos (${_memories.length})');
      }
    } else {
      _goToFirstMemory();
    }
  }

  LatLngBounds _calculateBounds() {
    double minLat = _memories[0].toLatLng.latitude;
    double maxLat = _memories[0].toLatLng.latitude;
    double minLng = _memories[0].toLatLng.longitude;
    double maxLng = _memories[0].toLatLng.longitude;

    for (var memory in _memories) {
      minLat = math.min(minLat, memory.toLatLng.latitude);
      maxLat = math.max(maxLat, memory.toLatLng.latitude);
      minLng = math.min(minLng, memory.toLatLng.longitude);
      maxLng = math.max(maxLng, memory.toLatLng.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _navigateToCoordinateInput() async {
    final LatLng? selectedLocation = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (context) => const CoordinateInputScreen(),
      ),
    );

    if (selectedLocation != null) {
      _showMemoryForm(selectedLocation);
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
          onShowAllMemories: _goToAllMemories,
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
      barrierDismissible: false,
      builder: (context) {
        return MemoryForm(
          location: location,
          existingMemory: existingMemory,
          onSave: (memory) async {
            try {
              await _memoryService.saveMemory(memory);
              Navigator.of(context).pop();
              _loadMemories();
              _showSnackbar(
                existingMemory == null 
                  ? 'Recuerdo creado' 
                  : 'Recuerdo actualizado'
              );
            } catch (e) {
              _showSnackbar('Error al guardar: $e', isError: true);
            }
          },
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  // --- EDICIÓN Y DETALLES ---
  Future<void> _editOnlyLocation(Memory memory) async {
    if (Navigator.canPop(context)) Navigator.pop(context);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoordinateInputScreen(existingMemory: memory),
      ),
    );

    if (result != null && result is Memory) {
      await _memoryService.saveMemory(result);
      _loadMemories();
      _showSnackbar('Ubicación actualizada');
    }
  }

  void _showMemoryDetails(Memory memory) {
    if (Navigator.canPop(context)) Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MemoryDetailScreen(
          memory: memory,
          onEdit: () => _editOnlyLocation(memory),
          onDelete: () async {
            Navigator.of(context).pop();
            await _confirmDeleteMemory(memory);
          },
          onUpdate: (updatedMemory) async {
            await _memoryService.saveMemory(updatedMemory);
            _loadMemories();
            _showSnackbar('Recuerdo actualizado');
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteMemory(Memory memory) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Recuerdo'),
        content: Text('¿Estás seguro de eliminar "${memory.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _memoryService.deleteMemory(memory.id);
        _loadMemories();
        _showSnackbar('${memory.title} eliminado');
      } catch (e) {
        _showSnackbar('Error al eliminar: $e', isError: true);
      }
    }
  }

  Future<void> _confirmClearAllMemories() async {
    if (Navigator.canPop(context)) Navigator.pop(context);
    
    if (_memories.isEmpty) {
      _showSnackbar('No hay recuerdos para eliminar', isError: true);
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Todos los Recuerdos'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar Todo',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _memoryService.clearAllMemories();
        _loadMemories();
        _showSnackbar('Todos los recuerdos eliminados');
      } catch (e) {
        _showSnackbar('Error al eliminar: $e', isError: true);
      }
    }
  }

  // --- MAPA WEB CON FLUTTER MAP ---
  Widget _buildWebMap() {
    return Scaffold(
      body: Stack(
        children: [
          fmap.FlutterMap(
            options: fmap.MapOptions(
              initialCenter: latlong2.LatLng(40.4168, -3.7038),
              initialZoom: 15.0,
            ),
            children: [
              fmap.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.memory_places',
              ),
              fmap.RichAttributionWidget(
                attributions: [
                  fmap.TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
              // Agregar marcadores para web usando MarkerLayer
              if (_memories.isNotEmpty)
                fmap.MarkerLayer(
                  markers: _buildWebMarkers(),
                ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: pinkPrimary),
            ),
        ],
      ),
    );
  }

  List<fmap.Marker> _buildWebMarkers() {
    return _memories.map((memory) {
      return fmap.Marker(
        point: latlong2.LatLng(
          memory.toLatLng.latitude,
          memory.toLatLng.longitude,
        ),
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () => _showMemoryDetails(memory),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pinkPrimary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.white,
                child: memory.imageAsset != null && memory.imageAsset!.isNotEmpty
                    ? Image.network(
                        memory.imageAsset!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: pinkLighter,
                          child: Icon(Icons.photo, color: pinkPrimary, size: 30),
                        ),
                      )
                    : Container(
                        color: pinkLighter,
                        child: Icon(Icons.photo, color: pinkPrimary, size: 30),
                      ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // --- MÉTODOS AUXILIARES ---
  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : pinkPrimary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    // 1. OBTENER EL TEMA ACTUAL
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    // 2. CONFIGURAR COLORES SEGÚN EL MODO
    final Color appBarBg = isDarkMode ? backgroundDark : backgroundLight;
    final Color titleColor = isDarkMode ? textDarkMode : textDark;
    final Color iconColor = pinkPrimary;
    final Color progressColor = pinkPrimary; // Color para el loading indicator

    // Si es web y estamos en modo biblioteca
    if (_isWeb && widget.isLibrary) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Memory Places',
            style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: appBarBg,
          elevation: 1,
          actions: [
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: CircularProgressIndicator(color: progressColor),
              ),
            IconButton(
              icon: Icon(Icons.menu, color: iconColor),
              onPressed: _showMenuDialog,
            ),
          ],
        ),
        body: _buildWebMap(),
      );
    }

    // Si es web pero NO es biblioteca (modo selección)
    if (_isWeb && !widget.isLibrary) {
      return _buildWebMap();
    }

    // Para móvil - Modo biblioteca
    if (widget.isLibrary) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Memory Places',
            style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: appBarBg,
          elevation: 1,
          actions: [
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: CircularProgressIndicator(color: pinkPrimary),
              ),
            IconButton(
              icon: Icon(Icons.menu, color: iconColor),
              onPressed: _showMenuDialog,
            ),
          ],
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(40.4168, -3.7038),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                mapController = controller;
                mapController.setMapStyle(mapStyle);
                if (widget.onMapCreatedCallback != null) {
                  widget.onMapCreatedCallback!(controller);
                }
                _loadMemories();
              },
              onCameraMove: (position) {
                _currentCameraPosition = position.target;
                // ESTO HACE QUE LAS COORDENADAS CAMBIEN EN TIEMPO REAL
                if (widget.onCameraMoveCallback != null) {
                  widget.onCameraMoveCallback!(position.target);
                }
              },
              markers: _markers,
              onLongPress: (position) {
                if (widget.onLongPressCallback != null) {
                  widget.onLongPressCallback!(position, mapController);
                } else {
                  _onMapLongPress(position);
                }
              },
              zoomControlsEnabled: true,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: pinkPrimary),
              ),
          ],
        ),
      );
    }

    // Para móvil - Modo NO biblioteca (selección de coordenadas)
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.initialMarkers?.isNotEmpty == true 
            ? widget.initialMarkers!.first.position 
            : const LatLng(40.4168, -3.7038),
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
        // MUY IMPORTANTE: Actualizar el callback aquí también
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
}