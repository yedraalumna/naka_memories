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
import '../widget/memory_form.dart';
import '../widget/memory_detail_screen.dart';
import '../widget/menu_dialog.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import '../constants/map_style.dart';
import '../screens/coordinate_input_screen.dart';
import '../providers/theme_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../providers/favorite_provider.dart';
import '../services/pdfService.dart';
import '../providers/app_auth_provider.dart';
import '../widget/pin_dialog.dart';
import '../widget/CategoryManager.dart';
import '../providers/category_provider.dart';

/// Pantalla principal que renderiza el mapa (Google Maps en móvil, FlutterMap en Web)
/// gestiona la visualización de los recuerdos, filtrado por categorías,
/// y navegación hacia la creación/edición de memorias
class MapScreen extends StatefulWidget {
  final bool isLibrary;
  final Set<Marker>? initialMarkers;
  final Function(GoogleMapController)? onMapCreatedCallback;
  final Function(LatLng)? onCameraMoveCallback;
  final Function(LatLng, GoogleMapController)? onLongPressCallback;

  const MapScreen({
    super.key,
    this.isLibrary = true,
    this.initialMarkers,
    this.onMapCreatedCallback,
    this.onCameraMoveCallback,
    this.onLongPressCallback,
  });

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
  String _selectedCategory = 'Todas';
  final Set<String> _unlockedCategories = {};
  bool _showPrivateInAll = false;
  bool get _isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    // Cargar recuerdos
    _loadMemories().then((_) {
      // Cuando se cargan, sincronizar el provider
      if (mounted) {
        Provider.of<FavoriteProvider>(context, listen: false)
            .loadFavorites(_memories);
      }
    });
  }

  /// Abre el gestor de categorías y recarga el mapa al volver para que se vean los cambios
  void _openCategoryManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryManager(),
      ),
    ).then((_) {
      _loadMemories();
    });
  }

  /// Muestra un modal con las opciones disponibles para la categoría seleccionada (renombrar/eliminar)
  void _showCategoryOptions(String categoryName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Opciones de: $categoryName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: pinkPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Opción renombrar
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline,
                    color: Colors.blue),
                title: const Text('Renombrar carpeta'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameCategoryDialog(categoryName);
                },
              ),

              // Opción eliminar (excepto para "General" que es la carpeta por defecto)
              if (categoryName != 'General')
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.red),
                  title: const Text('Eliminar esta carpeta'),
                  subtitle: const Text('Los recuerdos se moverán a "General"'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteCategory(categoryName);
                  },
                ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// Método que muestra el cuadro de diálogo para introducir un nuevo nombre para una categoría existente
  Future<void> _showRenameCategoryDialog(String oldName) async {
    final TextEditingController controller =
        TextEditingController(text: oldName);

    // Capturar temas para usarlos dentro del diálogo
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final catProvider = Provider.of<CategoryProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? cardDark : Colors.white,
        title: const Text('Renombrar Carpeta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: isDarkMode ? textDarkMode : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Nuevo nombre',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: pinkPrimary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                Navigator.pop(context, newName);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: pinkPrimary,
            ),
            child: const Text('Renombrar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await catProvider.renameCategory(oldName, result);

        if (!mounted) return;

        setState(() {
          _selectedCategory = result;
        });

        await _loadMemories();

        if (!mounted) return;
        _showSnackbar('Carpeta actualizada con éxito');
      } catch (e) {
        if (!mounted) return;
        _showSnackbar('Error: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  /// Método que confirma con el usuario si desea eliminar una categoría y, de ser así, la elimina moviendo sus recuerdos a "General"
  Future<void> _confirmDeleteCategory(String categoryName) async {
    if (categoryName == 'General') {
      _showSnackbar('No se puede eliminar la carpeta "General"', isError: true);
      return;
    }

    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? cardDark : Colors.white,
        title: const Text('Eliminar Carpeta'),
        content: Text(
          '¿Estás seguro de eliminar la carpeta "$categoryName"?\n\n'
          'Todos los recuerdos de esta carpeta se moverán a "General".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _memoryService.deleteCategory(categoryName);

        if (!mounted) return;

        setState(() {
          _selectedCategory = 'Todas';
        });
        await _loadMemories();

        if (!mounted) return;
        _showSnackbar('Carpeta "$categoryName" eliminada');
      } catch (e) {
        if (!mounted) return;
        _showSnackbar('Error al eliminar: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  /// Método que transforma la imagen (o la miniatura del video) en un icono de mapa cuadrado personalizado
  Future<BitmapDescriptor> _getMarkerIconSquare(String? path) async {
    const int targetWidth = 80;
    const double borderRadius = 12.0;
    const double borderWidth = 3.0;

    Uint8List? bytes;
    bool isVideo = path != null && path.toLowerCase().contains('.mp4');

    if (path == null || path.isEmpty) {
      return await _createDefaultMarkerIconSquare();
    }
    try {
      if (isVideo) {
        if (!_isWeb) {
          try {
            bytes = await VideoThumbnail.thumbnailData(
              video: path,
              imageFormat: ImageFormat.PNG,
              maxWidth: targetWidth,
              quality: 50,
            );
          } catch (e) {
            debugPrint("Fallo en la miniatura (usando icono por defecto): $e");
          }
        }
      } else {
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

      // Si no se pudieron cargar los bytes, usar el icono por defecto
      if (bytes == null) {
        return await _createDefaultMarkerIconSquare(isVideo: isVideo);
      }

      // Si se pudieron cargar los bytes, crear el icono personalizado
      ui.Codec codec =
          await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
      ui.FrameInfo fi = await codec.getNextFrame();

      final pictureRecorder = ui.PictureRecorder();
      final canvas = ui.Canvas(pictureRecorder);
      final paint = ui.Paint();

      final rect = ui.Rect.fromLTWH(
          0, 0, targetWidth.toDouble(), targetWidth.toDouble());
      const innerRect = ui.Rect.fromLTWH(borderWidth, borderWidth,
          targetWidth - (borderWidth * 2), targetWidth - (borderWidth * 2));

      paint.color = pinkPrimary;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
            rect, const ui.Radius.circular(borderRadius)),
        paint,
      );

      paint.color = Colors.white;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
            innerRect, const ui.Radius.circular(borderRadius - borderWidth)),
        paint,
      );

      final clipPath = ui.Path()
        ..addRRect(ui.RRect.fromRectAndRadius(
            innerRect, const ui.Radius.circular(borderRadius - borderWidth)));

      canvas.clipPath(clipPath);

      canvas.drawImageRect(
        fi.image,
        ui.Rect.fromLTWH(
            0, 0, fi.image.width.toDouble(), fi.image.height.toDouble()),
        innerRect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );

      if (isVideo) {
        paint.color = Colors.black45;
        canvas.drawRect(innerRect, paint);

        const iconPlay = Icons.play_circle_fill;
        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(iconPlay.codePoint),
            style: TextStyle(
              fontSize: targetWidth * 0.4,
              fontFamily: iconPlay.fontFamily,
              color: Colors.white.withValues(alpha: 0.9),
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

      return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    } catch (e) {
      return await _createDefaultMarkerIconSquare(isVideo: isVideo);
    }
  }

  /// Método que crea un marcador cuadrado por defecto si no hay imagen o falla la carga
  Future<BitmapDescriptor> _createDefaultMarkerIconSquare(
      {bool isVideo = false}) async {
    const double size = 80.0;
    const double borderRadius = 12.0;
    const double borderWidth = 3.0;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);
    final paint = ui.Paint();

    const rect = ui.Rect.fromLTWH(0, 0, size, size);
    const innerRect = ui.Rect.fromLTWH(borderWidth, borderWidth,
        size - (borderWidth * 2), size - (borderWidth * 2));

    paint.color = pinkPrimary;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(borderRadius)),
      paint,
    );

    paint.color = isVideo ? Colors.black87 : Colors.white;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
          innerRect, const ui.Radius.circular(borderRadius - borderWidth)),
      paint,
    );

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
    paragraph.layout(const ui.ParagraphConstraints(width: size));

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

    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }

  /// Método que carga los recuerdos desde la base de datos, aplicando los filtros de categoría, acceso, y genera los marcadores para el mapa
  Future<void> _loadMemories() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.loadCategories();

      final allMemories = await _memoryService.getMemories();

      final uniqueCategories = allMemories.map((m) => m.category).toSet();
      for (var cat in uniqueCategories) {
        final isProtected = categoryProvider.isCategoryProtected(cat);
        debugPrint('$cat: ${isProtected ? "PROTEGIDA" : "PÚBLICA"}');
        if (isProtected) {
          final hash = categoryProvider.getPasswordHash(cat);
          debugPrint(
              '      Hash: ${hash != null ? hash.substring(0, 20) : "null"}...');
        }
      }

      List<Memory> finalMemories;

      if (_selectedCategory == 'Todas') {
        if (_showPrivateInAll) {
          finalMemories = allMemories.where((memory) {
            final bool hasPassword =
                categoryProvider.isCategoryProtected(memory.category);
            if (!hasPassword) return true;
            return _unlockedCategories.contains(memory.category);
          }).toList();
        } else {
          finalMemories = allMemories.where((memory) {
            return !categoryProvider.isCategoryProtected(memory.category);
          }).toList();
        }
      } else {
        finalMemories =
            allMemories.where((m) => m.category == _selectedCategory).toList();
      }

      Set<Marker> newMarkers = {};
      for (var memory in finalMemories) {
        try {
          final icon = await _getMarkerIconSquare(memory.imageAsset);
          newMarkers.add(
            Marker(
              markerId: MarkerId(memory.id),
              position: memory.toLatLng,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(
                title: memory.title,
                snippet: memory.category,
                onTap: () => _showMemoryDetails(memory),
              ),
              onTap: () => _showMemoryDetails(memory),
            ),
          );
        } catch (e) {
          debugPrint("Error marcador: $e");
        }
      }

      if (mounted) {
        setState(() {
          _memories = allMemories;
          _markers = newMarkers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Error al cargar recuerdos: $e');
      }
    }
  }

  /// Método que construye la barra superior horizontal deslizable con las categorías disponibles
  Widget _buildFiltersOverlay() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final listadoCategorias = categoryProvider.categories;
    final categoriasConTodas = ['Todas', ...listadoCategorias];

    Color backgroundColor = isDarkMode ? cardDark : Colors.white;

    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 45,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: categoriasConTodas.length,
          itemBuilder: (context, index) {
            final cat = categoriasConTodas[index];
            final isSelected = _selectedCategory == cat;

            return GestureDetector(
              onTap: () => _onCategoryTap(cat),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? pinkPrimary : backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: pinkPrimary,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : pinkPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Método de gestión de acceso al tocar una categoría (validación de PIN si tiene)
  void _onCategoryTap(String categoryName) async {
    if (categoryName == 'Todas') {
      final bool? incluirPrivadas = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ver carpetas protegidas'),
          content: const Text(
              '¿Quieres ver los recuerdos de tus carpetas con contraseña?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, solo públicas'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, incluir privadas'),
            ),
          ],
        ),
      );

      if (incluirPrivadas == null) return;
      if (!mounted) return;

      if (incluirPrivadas) {
        await _requestPinsForAllProtectedCategories();
      }

      if (mounted) {
        setState(() {
          _selectedCategory = 'Todas';
          _showPrivateInAll = incluirPrivadas;
          if (!incluirPrivadas) {
            _unlockedCategories.clear();
          }
        });
        _loadMemories();
      }
      return;
    }

    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    final bool hasPassword = categoryProvider.isCategoryProtected(categoryName);

    if (hasPassword) {
      if (_unlockedCategories.contains(categoryName)) {
        debugPrint('   Ya desbloqueada en esta sesión');
        setState(() {
          _selectedCategory = categoryName;
        });
        _loadMemories();
        return;
      }

      final String? passwordHash =
          categoryProvider.getPasswordHash(categoryName);

      if (passwordHash != null) {
        debugPrint('   Mostrando diálogo PIN...');
        final bool? isAuthorized = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PinDialog(
            correctHash: passwordHash,
            titulo: 'Carpeta Protegida: $categoryName',
          ),
        );

        if (!mounted) return;

        if (isAuthorized == true) {
          setState(() {
            _unlockedCategories.add(categoryName);
            _selectedCategory = categoryName;
          });
          _loadMemories();
          _showSnackbar('Carpeta desbloqueada: $categoryName');
        } else {
          _showSnackbar('Acceso denegado a: $categoryName', isError: true);
        }
      }
    } else {
      setState(() {
        _selectedCategory = categoryName;
      });
      _loadMemories();
    }
  }

  /// Método que despliega cuadros de diálogo consecutivos para desbloquear todas las categorías privadas
  Future<void> _requestPinsForAllProtectedCategories() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final protectedCategories = categoryProvider.categories
        .where((cat) => categoryProvider.isCategoryProtected(cat))
        .toList();

    if (protectedCategories.isEmpty) return;

    for (int i = 0; i < protectedCategories.length; i++) {
      if (!mounted) return;

      final categoryName = protectedCategories[i];
      if (_unlockedCategories.contains(categoryName)) continue;

      final passwordHash = categoryProvider.getPasswordHash(categoryName);
      if (passwordHash == null || passwordHash.isEmpty) continue;

      final bool? isAuthorized = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PinDialog(
          correctHash: passwordHash,
          titulo:
              'PIN de: $categoryName (${i + 1}/${protectedCategories.length})',
        ),
      );

      if (!mounted) return;
      if (isAuthorized == true) {
        _unlockedCategories.add(categoryName);
      }
    }
  }

  // manejamos el menú y la navegación
  void _handleSaveCoordinatesFromMenu() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    _navigateToCoordinateInput();
  }

  // Abre directamente el formulario con la posición actual
  void _openMemoryFormDirectly() {
    if (Navigator.canPop(context)) Navigator.pop(context);

    _showMemoryForm(_currentCameraPosition);
  }

  /// Método que enfoca la cámara del mapa para que se vean todos los recuerdos visibles
  void _goToAllMemories() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // filtrar solo memorias visibles (públicas y privadas desbloqueadas)
    final visibleMemories = _memories.where((memory) {
      final bool hasPassword =
          categoryProvider.isCategoryProtected(memory.category);
      if (!hasPassword) return true;
      return _unlockedCategories.contains(memory.category);
    }).toList();

    if (visibleMemories.length > 1) {
      if (!_isWeb) {
        // Calcular bounds con las memorias visibles
        LatLngBounds bounds = _calculateBoundsForList(visibleMemories);
        mapController.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
        Navigator.pop(context);
        _showSnackbar('Mostrando ${visibleMemories.length} recuerdos visibles');
      } else {
        Navigator.pop(context);
        _showSnackbar('Mostrando ${visibleMemories.length} recuerdos visibles');
      }
    } else if (visibleMemories.length == 1) {
      final firstMemory = visibleMemories.first;
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
      _showSnackbar('No hay recuerdos visibles', isError: true);
    }
  }

  // Función que calcula los límites (bounds) de una lista específica de recuerdos para centrar el mapa en ellos
  LatLngBounds _calculateBoundsForList(List<Memory> list) {
    double minLat = list[0].toLatLng.latitude;
    double maxLat = list[0].toLatLng.latitude;
    double minLng = list[0].toLatLng.longitude;
    double maxLng = list[0].toLatLng.longitude;

    for (var memory in list) {
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

  // Función para centrar el mapa en la lista
  void _centerMapOnList(List<Memory> list) {
    if (list.isEmpty) return;

    if (!_isWeb) {
      // calcular los límites (bounds) de esta lista específica
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

      // mover la cámara del mapa
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

  /// Método que navega a la pantalla de selección manual de coordenadas para crear un nuevo recuerdo en esa ubicación
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

  /// Despliega el menú principal inferior con las opciones de gestión de los recuerdos y categorías
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
          onCreateNewMemory: _openMemoryFormDirectly,
          onClearAllMemories: _confirmClearAllMemories,
          onShowMemoryDetails: _showMemoryDetails,
          onCenterList: _centerMapOnList,
          onGenerarPdf: _gestionarPdf,
        );
      },
    );
  }

  /// Cuadro de diálogo para seleccionar qué categorías exportar a PDF
  Future<Set<String>?> _showPdfCategorySelector(
    List<String> categories,
    CategoryProvider categoryProvider,
  ) async {
    final Set<String> selected = categories.toSet();

    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('Selecciona carpetas a exportar'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setLocalState(() {
                            selected
                              ..clear()
                              ..addAll(categories);
                          });
                        },
                        child: const Text('Todas'),
                      ),
                      TextButton(
                        onPressed: () {
                          setLocalState(selected.clear);
                        },
                        child: const Text('Ninguna'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isProtected =
                            categoryProvider.isCategoryProtected(category);

                        return CheckboxListTile(
                          value: selected.contains(category),
                          onChanged: (value) {
                            setLocalState(() {
                              if (value == true) {
                                selected.add(category);
                              } else {
                                selected.remove(category);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(category),
                          secondary: isProtected
                              ? const Icon(Icons.lock, color: pinkPrimary)
                              : const Icon(Icons.folder_open,
                                  color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
                onPressed: () => Navigator.pop(ctx, Set<String>.from(selected)),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Método que prepara y autoriza los datos necesarios para generar un PDF de los recuerdos
  Future<void> _gestionarPdf() async {
    final List<Memory> listaCopia = List.from(_memories);
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final userName =
        auth.userMetadata?['full_name'] ?? auth.user?.email ?? 'Usuario';

    if (listaCopia.isEmpty) {
      _showSnackbar('No hay recuerdos para exportar', isError: true);
      return;
    }

    final categories = listaCopia.map((m) => m.category).toSet().toList()
      ..sort();
    final selectedCategories =
        await _showPdfCategorySelector(categories, categoryProvider);

    if (!mounted || selectedCategories == null) return;
    if (selectedCategories.isEmpty) {
      _showSnackbar('Selecciona al menos una carpeta', isError: true);
      return;
    }

    final selectedMemories = listaCopia
        .where((m) => selectedCategories.contains(m.category))
        .toList();

    final privateSelectedCategories = selectedCategories
        .where((c) => categoryProvider.isCategoryProtected(c))
        .toList();

    final Set<String> unlockedForPdf = {};
    for (int i = 0; i < privateSelectedCategories.length; i++) {
      if (!mounted) return;

      final category = privateSelectedCategories[i];
      final hash = categoryProvider.getPasswordHash(category);

      if (hash == null || hash.isEmpty) continue;

      final bool? pinCorrecto = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PinDialog(
          correctHash: hash,
          titulo:
              'PIN de: $category (${i + 1}/${privateSelectedCategories.length})',
        ),
      );

      if (!mounted) return;
      if (pinCorrecto == true) {
        unlockedForPdf.add(category);
      }
    }

    final exportList = selectedMemories.where((m) {
      final isProtected = categoryProvider.isCategoryProtected(m.category);
      if (!isProtected) return true;
      return unlockedForPdf.contains(m.category);
    }).toList();

    if (exportList.isEmpty) {
      _showSnackbar('No hay recuerdos autorizados para exportar',
          isError: true);
      return;
    }

    exportList.sort((a, b) => b.date.compareTo(a.date));
    PdfService().generarPdf(exportList, userName);

    final omittedPrivate =
        privateSelectedCategories.length - unlockedForPdf.length;
    if (omittedPrivate > 0) {
      _showSnackbar(
        'PDF generado. Se omitieron $omittedPrivate carpetas privadas no verificadas.',
      );
    }
  }

  /// Método que se ejecuta al mantener presionado el mapa móvil
  void _onMapLongPress(LatLng position) {
    if (!_isWeb) {
      mapController.animateCamera(CameraUpdate.newLatLng(position));
    }
    _showMemoryForm(position);
  }

  /// Método que muestra el formulario para crear o editar un recuerdo en una ubicación específica
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
              Navigator.of(context).pop();
              _loadMemories();

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

  // Método de edición de solo ubicación desde el detalle del recuerdo
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
      if (!mounted) return;
      _loadMemories();
      _showSnackbar('Ubicación actualizada');
    }
  }

  /// Método que levanta la hoja de detalle completa al pulsar sobre un marcador del mapa
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

            if (!mounted) return;

            _loadMemories();
            _showSnackbar('Recuerdo actualizado');
          },
        );
      },
    );
  }

  /// Método de diálogo de confirmación antes de eliminar un recuerdo de la base de datos
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

        if (!mounted) return;

        _loadMemories();
        _showSnackbar('${memory.title} eliminado');
      } catch (e) {
        if (!mounted) return;
        _showSnackbar('Error al eliminar: $e', isError: true);
      }
    }
  }

  /// Método de diálogo de advertencia extrema para limpiar por completo el mapa del usuario
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

        if (!mounted) return;

        _loadMemories();
        _showSnackbar('Todos los recuerdos eliminados');
      } catch (e) {
        if (!mounted) return;
        _showSnackbar('Error al eliminar: $e', isError: true);
      }
    }
  }

  // mapa para web usando flutter_map
  Widget _buildWebMap() {
    return Stack(
      children: [
        fmap.FlutterMap(
          options: const fmap.MapOptions(
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
            if (_memories.isNotEmpty)
              fmap.MarkerLayer(
                markers: _buildWebMarkers(),
              ),
          ],
        ),
        if (widget.isLibrary) _buildFiltersOverlay(),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: pinkPrimary),
          ),
      ],
    );
  }

  /// Lista de los pines interactivos del mapa específico para la versión web
  List<fmap.Marker> _buildWebMarkers() {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // filtrar según permisos
    final visibleMemories = _memories.where((memory) {
      final bool hasPassword =
          categoryProvider.isCategoryProtected(memory.category);
      if (!hasPassword) return true;
      return _unlockedCategories.contains(memory.category);
    }).toList();

    // aplicar filtro de categoría seleccionada
    final filteredList = _selectedCategory == 'Todas'
        ? visibleMemories
        : visibleMemories
            .where((m) => m.category == _selectedCategory)
            .toList();

    return filteredList.map((memory) {
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
                  color: Colors.black.withValues(alpha: 0.3),
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
                          child: const Icon(Icons.photo,
                              color: pinkPrimary, size: 30),
                        ),
                      )
                    : Container(
                        color: pinkLighter,
                        child: const Icon(Icons.photo,
                            color: pinkPrimary, size: 30),
                      ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // métodos para mostrar mensajes al usuario
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

  /// Método que muestra un modal nativo de error general en caso de excepciones graves
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    final Color appBarBg = isDarkMode ? backgroundDark : backgroundLight;
    final Color titleColor = isDarkMode ? textDarkMode : textDark;
    const Color iconColor = pinkPrimary;

    AppBar buildAppBar() {
      return AppBar(
        title: Text(
          _selectedCategory == 'Todas' ? 'Memory Places' : _selectedCategory,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: appBarBg,
        elevation: 1,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child:
                  CircularProgressIndicator(color: pinkPrimary, strokeWidth: 2),
            ),
          // Botón de editar (solo si hay categoría seleccionada)
          if (_selectedCategory != 'Todas')
            IconButton(
              icon: const Icon(Icons.edit, color: pinkPrimary),
              onPressed: () => _showCategoryOptions(_selectedCategory),
              tooltip: 'Opciones de carpeta',
            ),
          // Botón para gestionar carpetas
          IconButton(
            icon: const Icon(Icons.folder, color: iconColor),
            onPressed: _openCategoryManager,
            tooltip: 'Gestionar carpetas',
          ),
          // Botón menú principal
          IconButton(
            icon: const Icon(Icons.menu, color: iconColor),
            onPressed: _showMenuDialog,
            tooltip: 'Menú principal',
          ),
        ],
      );
    }

    // Si es web y estamos en modo biblioteca, mostramos el mapa con la barra de filtros
    if (_isWeb && widget.isLibrary) {
      return Scaffold(
        appBar: buildAppBar(),
        body: _buildWebMap(),
      );
    }

    // Si es web pero no es biblioteca (modo selección de coordenadas)
    if (_isWeb && !widget.isLibrary) {
      return _buildWebMap();
    }

    // Si es movil en modo biblioteca (mapa con filtros y gestión de recuerdos)
    if (widget.isLibrary) {
      return Scaffold(
        appBar: buildAppBar(),
        body: Stack(
          children: [
            GoogleMap(
              style: mapStyle,
              initialCameraPosition: const CameraPosition(
                target: LatLng(40.4168, -3.7038),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                mapController = controller;

                if (widget.onMapCreatedCallback != null) {
                  widget.onMapCreatedCallback!(controller);
                }
                _loadMemories();
              },
              onCameraMove: (position) {
                _currentCameraPosition = position.target;
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
              zoomControlsEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
            _buildFiltersOverlay(),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: pinkPrimary),
              ),
          ],
        ),
      );
    }

    // Si es movil y no es biblioteca, solo mostramos el mapa para selección de coordenadas sin filtros ni gestión de recuerdos
    return GoogleMap(
      style: mapStyle,
      initialCameraPosition: CameraPosition(
        target: widget.initialMarkers?.isNotEmpty == true
            ? widget.initialMarkers!.first.position
            : const LatLng(40.4168, -3.7038),
        zoom: 15,
      ),
      onMapCreated: (controller) {
        mapController = controller;

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
