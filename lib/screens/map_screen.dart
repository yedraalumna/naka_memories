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
import 'package:video_thumbnail/video_thumbnail.dart'; // pa la miniatura del video
import '../providers/favorite_provider.dart';

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
  String _selectedCategory = 'Todos'; // Filtros
  List<String> _dynamicCategories = []; // Lista de categorias

  // Detectar si es web
  bool get _isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    // 1. Cargar recuerdos
    _loadMemories().then((_) {
      // 2. Una vez cargados, sincronizar el provider
      if (mounted) {
        Provider.of<FavoriteProvider>(context, listen: false)
            .loadFavorites(_memories);
      }
    });
  }

  // crea marcador cuadrado con bordes redondeados
  Future<BitmapDescriptor> _getMarkerIconSquare(String? path) async {
    const int targetWidth = 80;
    const double borderRadius = 12.0;
    const double borderWidth = 3.0;

    Uint8List?
        bytes; // el "?" es pa que permita nulos pq crea confrontacion con la miniatura del video
    bool isVideo = path != null && path.toLowerCase().contains('.mp4');

    if (path == null || path.isEmpty) {
      return await _createDefaultMarkerIconSquare();
    }
    try {
      if (isVideo) {
        // En WEB saltamos directo al fallback (cuadrado negro) porque video_thumbnail suele fallar
        if (!_isWeb) {
          try {
            bytes = await VideoThumbnail.thumbnailData(
              video: path,
              imageFormat: ImageFormat.PNG,
              maxWidth: targetWidth,
              quality: 50,
            );
          } catch (e) {
            debugPrint("Fallo miniatura (usando icono por defecto): $e");
          }
        }
      } else {
        // carga de imagenes normal
        if (path.startsWith('assets/')) {
          ByteData data = await rootBundle.load(path);
          bytes = data.buffer.asUint8List();
        } else if (_isWeb || path.startsWith('http')) {
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) bytes = response.bodyBytes;
        } else {
          final file = File(path);
          if (await file.exists()) bytes = await file.readAsBytes();
        }
      }

      // Si bytes sigue siendo null (falló miniatura o carga),
      // devolvemos el marcador genérico
      if (bytes == null) {
        return await _createDefaultMarkerIconSquare(isVideo: isVideo);
      }

      // 2. Redimensionamos la imagen
      ui.Codec codec =
          await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
      ui.FrameInfo fi = await codec.getNextFrame();

      final pictureRecorder = ui.PictureRecorder();
      final canvas = ui.Canvas(pictureRecorder);
      final paint = ui.Paint();

      final rect = ui.Rect.fromLTWH(
          0, 0, targetWidth.toDouble(), targetWidth.toDouble());
      final innerRect = ui.Rect.fromLTWH(borderWidth, borderWidth,
          targetWidth - (borderWidth * 2), targetWidth - (borderWidth * 2));

      // Dibujamos fondo con borde rosado
      paint.color = pinkPrimary;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(borderRadius)),
        paint,
      );

      // Dibujamos fondo interior blanco
      paint.color = Colors.white;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
            innerRect, ui.Radius.circular(borderRadius - borderWidth)),
        paint,
      );

      // Recortamos con bordes redondeados
      final clipPath = ui.Path()
        ..addRRect(ui.RRect.fromRectAndRadius(
            innerRect, ui.Radius.circular(borderRadius - borderWidth)));

      canvas.clipPath(clipPath);

      // Dibujamos la imagen
      canvas.drawImageRect(
        fi.image,
        ui.Rect.fromLTWH(
            0, 0, fi.image.width.toDouble(), fi.image.height.toDouble()),
        innerRect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );

      // Icono Play si es video
      if (isVideo) {
        paint.color = Colors.black45;
        canvas.drawRect(innerRect, paint);

        final iconPlay = Icons.play_circle_fill;
        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(iconPlay.codePoint),
            style: TextStyle(
              fontSize: targetWidth * 0.4,
              fontFamily: iconPlay.fontFamily,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
            canvas,
            Offset(targetWidth / 2 - textPainter.width / 2,
                targetWidth / 2 - textPainter.height / 2));
      }

      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(targetWidth, targetWidth);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    } catch (e) {
      // Fallback final
      return await _createDefaultMarkerIconSquare(isVideo: isVideo);
    }
  }

  Future<BitmapDescriptor> _createDefaultMarkerIconSquare(
      {bool isVideo = false}) async {
    const double size = 80.0;
    const double borderRadius = 12.0;
    const double borderWidth = 3.0;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);
    final paint = ui.Paint();

    final rect = ui.Rect.fromLTWH(0, 0, size, size);
    final innerRect = ui.Rect.fromLTWH(borderWidth, borderWidth,
        size - (borderWidth * 2), size - (borderWidth * 2));

    // Fondo con borde rosado
    paint.color = pinkPrimary;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(borderRadius)),
      paint,
    );

    // Fondo interior blanco (o negro si es video, para que destaque)
    paint.color = isVideo ? Colors.black87 : Colors.white; // CAMBIO
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
          innerRect, ui.Radius.circular(borderRadius - borderWidth)),
      paint,
    );

    // Si es video ponemos Play, si no, Foto
    final iconData = isVideo ? Icons.play_arrow : Icons.photo;

    final textStyle = ui.TextStyle(
      fontSize: size * 0.4,
      fontFamily: iconData.fontFamily,
      color: isVideo ? Colors.white : pinkPrimary,
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
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }

    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  // Cargamos los recuerdos con marcadores personalizados
  Future<void> _loadMemories() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final allMemories = await _memoryService.getMemories();

      // Logica de categorias
      // Las predefinidias
      Set<String> uniqueCategories = Set.from(Memory.categoriesList);

      // Se añaden las que vengan de los recuerdos
      for (var m in allMemories) {
        if (m.category.isNotEmpty) {
          uniqueCategories.add(m.category);
        }
      }

      // Se guardan en la lista
      _dynamicCategories = uniqueCategories.toList();

      final filteredList = _selectedCategory == 'Todas'
          ? allMemories
          : allMemories.where((m) => m.category == _selectedCategory).toList();

      // Creamos los marcadores SOLO para la lista filtrada
      Set<Marker> newMarkers = {};

      for (var memory in filteredList) {
        try {
          // Generamos el icono personalizado (foto o default)
          final icon = await _getMarkerIconSquare(memory.imageAsset);

          newMarkers.add(
            Marker(
              markerId: MarkerId(memory.id),
              position: memory.toLatLng,
              icon: icon,
              anchor: const Offset(0.5, 0.5), // Centramos el icono
              infoWindow: InfoWindow(
                title: memory.title,
                // Mostramos la categoría en el subtítulo del marcador
                snippet: memory.category,
                onTap: () => _showMemoryDetails(memory),
              ),
              onTap: () => _showMemoryDetails(memory),
            ),
          );
        } catch (e) {
          debugPrint(
              "Error creando marcador individual para ${memory.title}: $e");
          // Si falla un marcador específico, el bucle continúa con los demás
        }
      }

      // Actualizamos el estado
      setState(() {
        _memories = allMemories;
        _markers = newMarkers;
        _isLoading = false;
      });
    } catch (e) {
      // Manejo de errores general
      setState(() => _isLoading = false);
      _showErrorDialog('Error al cargar recuerdos: $e');
    }
  }

  // Función que crea un chip de filtro
  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedCategory == label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            // Si desmarcan el actual, volvemos a 'Todas', si no, ponemos la categoría
            if (!selected && label != 'Todas') {
              _selectedCategory = 'Todas';
            } else {
              _selectedCategory = label;
            }
          });
          // Recargamos los marcadores con el nuevo filtro
          _loadMemories();
        },
        backgroundColor: Colors.white,
        selectedColor: pinkPrimary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : pinkPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: pinkPrimary, width: 1),
        ),
        elevation: 2,
        pressElevation: 4,
      ),
    );
  }

  // manejamos el menú y la navegación
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
        // Calculamos bounds para incluir todos los marcadores
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

  // Función para centrar el mapa en la lista
  void _centerMapOnList(List<Memory> list) {
    if (list.isEmpty) return;

    if (!_isWeb) {
      // 1. Calculamos los límites (bounds) de esta lista específica
      double minLat = list.first.latitude;
      double maxLat = list.first.latitude;
      double minLng = list.first.longitude;
      double maxLng = list.first.longitude;

      for (var m in list) {
        minLat = math.min(minLat, m.latitude);
        maxLat = math.max(maxLat, m.latitude);
        minLng = math.min(minLng, m.longitude);
        maxLng = math.max(maxLng, m.longitude);
      }

      // 2. Movemos la cámara del mapa
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100, // Padding en píxeles
        ),
      );
    }
    _showSnackbar('Centrando en ${list.length} recuerdos');
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
          onCenterList: _centerMapOnList,
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
              // Borramos: await _memoryService.saveMemory(memory);
              // El formulario ya lo guardó, si lo dejamos aqui se guarda dos veces

              Navigator.of(context).pop(); // Cierra el diálogo
              _loadMemories(); // Recarga los marcadores

              _showSnackbar(existingMemory == null
                  ? 'Recuerdo creado'
                  : 'Recuerdo actualizado');
            } catch (e) {
              _showSnackbar('Error al refrescar: $e', isError: true);
            }
          },
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  // edicion de solo ubicación desde el detalle del recuerdo
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

  // mapa para web usando flutter_map
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
              // Agregamos marcadores para web usando MarkerLayer
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
                child: memory.imageAsset != null &&
                        memory.imageAsset!.isNotEmpty
                    ? Image.network(
                        memory.imageAsset!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: pinkLighter,
                          child:
                              Icon(Icons.photo, color: pinkPrimary, size: 30),
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

  // metodos para mostrar mensajes al usuario
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

  // Widget principal
  @override
  Widget build(BuildContext context) {
    // Obtenemos el estado del tema para configurar colores
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    // Configuramos colores dinámicos para la UI
    final Color appBarBg = isDarkMode ? backgroundDark : backgroundLight;
    final Color titleColor = isDarkMode ? textDarkMode : textDark;
    final Color iconColor = pinkPrimary;
    final Color progressColor = pinkPrimary;

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
        body:
            _buildWebMap(), // Nota: Si quieres filtros en web, deberías pasarlos a este método o poner el Stack aquí.
      );
    }

    // Si es web pero no es biblioteca (modo selección de coordenadas)
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
            // Mapa
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
                _loadMemories(); // Carga inicial con filtros
              },
              onCameraMove: (position) {
                _currentCameraPosition = position.target;
                if (widget.onCameraMoveCallback != null) {
                  widget.onCameraMoveCallback!(position.target);
                }
              },
              // Usamos _markers (que ya vienen filtrados por _loadMemories)
              markers: _markers,
              onLongPress: (position) {
                if (widget.onLongPressCallback != null) {
                  widget.onLongPressCallback!(position, mapController);
                } else {
                  _onMapLongPress(position);
                }
              },
              zoomControlsEnabled:
                  false, // Quitamos controles nativos para que no se solapen
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),

            // Filtros
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    _buildFilterChip('Todas'),

                    // AHORA USAMOS LA LISTA DINÁMICA _dynamicCategories EN LUGAR DE Memory.categoriesList
                    ..._dynamicCategories.map((category) {
                      return _buildFilterChip(category);
                    }).toList(),
                  ],
                ),
              ),
            ),

            // Indicador de carga
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: pinkPrimary),
              ),
          ],
        ),
      );
    }

    // Para móvil - Modo no biblioteca (selección de coordenadas)
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
