import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import 'MemoryForm.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MemoryDetailScreen extends StatefulWidget {
  // Antes era StatelessWidget, se cambia pq es necesario para video
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
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideo = false;
  bool _isInitVideoError = false;

  @override
  void initState() {
    super.initState();
    _checkMediaType(); // Comprobar si es video al iniciar
  }

  @override
  void didUpdateWidget(MemoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la URL cambia (gracias al paso 1), esto se activará y refrescará la imagen
    if (widget.memory.imageAsset != oldWidget.memory.imageAsset) {
      _disposeControllers();
      _checkMediaType();
    }
  }

  @override
  void dispose() {
    _disposeControllers(); // Limpiar memoria al salir
    super.dispose();
  }

  void _disposeControllers() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  // LÓGICA DE DETECCIÓN
  void _checkMediaType() {
    final path = widget.memory.imageAsset?.trim();
    if (path == null || path.isEmpty) return;

    // Detectar .mp4 permitiendo parámetros URL
    if (!path.startsWith('assets/') && path.toLowerCase().contains('.mp4')) {
      setState(() => _isVideo = true);
      _initializePlayer(path);
    } else {
      setState(() => _isVideo = false);
    }
  }

  Future<void> _initializePlayer(String path) async {
    try {
      if (kIsWeb || path.startsWith('http')) {
        _videoPlayerController =
            VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        _videoPlayerController = VideoPlayerController.file(File(path));
      }
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) => const Center(
            child: Text('Error video', style: TextStyle(color: Colors.white))),
      );
      if (mounted) setState(() {});
    } catch (e) {
      print("Error video: $e");
      if (mounted) setState(() => _isInitVideoError = true);
    }
  }

  Future<void> _shareMemory() async {
    // 1. Enlace limpio y oficial de Google Maps
    final String googleMapsLink =
        'https://www.google.com/maps/search/?api=1&query=${widget.memory.latitude},${widget.memory.longitude}';

    // 2. Texto del mensaje
    final String shareText = '''
Nayeka Memories - Recuerdo compartido

Título: ${widget.memory.title}
Descripción: ${widget.memory.description}
Fecha: ${widget.memory.date.split('T')[0]}

Ver ubicación en Maps: $googleMapsLink

Creado con Nayeka Memories: 
https://nayeka-memories.com
''';

    final mediaPath = widget.memory.imageAsset?.trim();

    try {
      // Si no hay imagen ni video, solo mandamos texto
      if (mediaPath == null || mediaPath.isEmpty) {
        await SharePlus.instance.share(ShareParams(text: shareText));
        return;
      }

      // LÓGICA PARA CHROME / WEB
      if (kIsWeb) {
        final mediaIcon = widget.memory.isVideo ? 'Video' : 'Imagen';
        // En web compartimos el enlace directamente
        await SharePlus.instance.share(
          ShareParams(text: '$shareText\n\n$mediaIcon: $mediaPath'),
        );
        return;
      }

      // LÓGICA PARA MÓVILES (Android/iOS)
      if (mediaPath.startsWith('http')) {
        // Aviso visual amplio y legible
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparando archivo...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            duration: Duration(seconds: 1),
            padding: EdgeInsets.all(20),
          ),
        );

        // Descarga y creación de archivo temporal
        final response = await http.get(Uri.parse(mediaPath));
        final tempDir = await getTemporaryDirectory();

        final extension = widget.memory.isVideo ? '.mp4' : '.jpg';
        final tempFile = File(
            '${tempDir.path}/recuerdo_${DateTime.now().millisecondsSinceEpoch}$extension');

        await tempFile.writeAsBytes(response.bodyBytes);

        // Enviamos el archivo físico nativo (Sintaxis moderna)
        await SharePlus.instance.share(
          ShareParams(
            text: shareText,
            files: [XFile(tempFile.path)],
          ),
        );
      } else if (!mediaPath.startsWith('assets/')) {
        // Archivo físico local preexistente (Sintaxis moderna)
        await SharePlus.instance.share(
          ShareParams(
            text: shareText,
            files: [XFile(mediaPath)],
          ),
        );
      } else {
        // Asset interno (Sintaxis moderna)
        await SharePlus.instance.share(ShareParams(text: shareText));
      }
    } catch (e) {
      print('Error al compartir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al compartir: $e',
              style: const TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.red,
            padding: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

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

  // Construimos la sección de imagen y video soportando archivos locales
  Widget _buildImage(bool isDarkMode) {
    final path = widget.memory.imageAsset?.trim();

    if (path != null && path.isNotEmpty) {
      // 1. SECCIÓN DE VIDEO
      if (_isVideo) {
        if (_isInitVideoError) return _buildErrorContainer(isDarkMode);
        if (_chewieController != null &&
            _videoPlayerController!.value.isInitialized) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            ),
          );
        } else {
          return Container(
            height: 250,
            decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(20)),
            child: const Center(
                child: CircularProgressIndicator(color: pinkPrimary)),
          );
        }
      }

      // 2. SECCIÓN DE FOTO (A TAMAÑO REAL)
      Widget imageWidget;

      // Configuramos la carga de la imagen
      if (path.startsWith('assets/')) {
        imageWidget = Image.asset(path, fit: BoxFit.contain);
      } else if (kIsWeb || path.startsWith('http')) {
        imageWidget = Image.network(
          path,
          key: ValueKey(path),
          fit: BoxFit.contain, // CLAVE: Muestra la foto entera sin recortar
          cacheWidth:
              1200, // Subimos la calidad para que se vea nítida en el detalle
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(
                height: 250,
                child: Center(
                    child: CircularProgressIndicator(color: pinkPrimary)));
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildErrorContainer(isDarkMode),
        );
      } else {
        imageWidget = Image.file(
          File(path),
          fit: BoxFit.contain, // Muestra la foto entera sin recortar
          cacheWidth: 1200,
          errorBuilder: (context, error, stackTrace) =>
              _buildErrorContainer(isDarkMode),
        );
      }

      return Container(
        constraints: const BoxConstraints(
            maxHeight:
                500), // Limitamos la altura máxima para que no ocupe toda la pantalla
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.black26
              : Colors
                  .grey[100], // Fondo sutil para las zonas que queden vacías
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: imageWidget,
        ),
      );
    }

    return _buildErrorContainer(isDarkMode); // Si no hay nada, error
  }

  // Widget auxiliar para control de errores de carga de imagen
  Widget _buildErrorContainer(bool isDarkMode) {
    return Container(
      height: 250,
      color: isDarkMode ? cardDark : pinkLighter,
      alignment: Alignment.center,
      child: const Icon(Icons.error, color: pinkPrimary, size: 50),
    );
  }

  // Muestra el título principal de la memoria
  Widget _buildTitle(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // categoría
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pinkPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: pinkPrimary.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getCategoryIcon(widget.memory.category),
                  size: 16, color: pinkPrimary),
              const SizedBox(width: 6),
              Text(
                widget.memory.category,
                style: const TextStyle(
                  color: pinkPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Titulo
        Text(
          widget.memory.title,
          style: TextStyle(
            color: isDarkMode ? textDarkMode : pinkDark,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // Helper de iconos (puedes ponerlo global en constants si prefieres no repetir)
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Viajes':
        return Icons.flight;
      case 'Amigos':
        return Icons.people;
      case 'Familia':
        return Icons.home;
      case 'Comida':
        return Icons.restaurant;
      case 'Estudio':
        return Icons.school;
      default:
        return Icons.bookmark;
    }
  }

  // mostramos la fecha del recuerdo con icono de calendario
  Widget _buildDate(bool isDarkMode) {
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: pinkPrimary, size: 18),
        const SizedBox(width: 8),
        Text(
          widget.memory.date,
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
          widget.memory.description,
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
            color: isDarkMode ? Colors.grey[700]! : pinkLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: pinkPrimary, size: 24),
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
              const Icon(Icons.north, color: pinkPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Latitud: ${widget.memory.latitude.toStringAsFixed(6)}',
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
              const Icon(Icons.east, color: pinkPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Longitud: ${widget.memory.longitude.toStringAsFixed(6)}',
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
        // Botón de Compartir Externamente
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _shareMemory,
            style: ElevatedButton.styleFrom(
              backgroundColor: pinkLighter,
              foregroundColor: pinkPrimary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 3,
            ),
            icon: const Icon(Icons.share, size: 28),
            label: const Text(
              'Compartir',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 15),

        // Botón de editar
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

        // Botón de eliminar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? cardDark : Colors.white,
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
                leading: const Icon(Icons.edit_location, color: pinkPrimary),
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
                  widget.onEdit();
                },
              ),

              Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),

              // Opción 2: Editar todos los datos
              ListTile(
                leading: const Icon(Icons.edit_note, color: pinkPrimary),
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
                leading: const Icon(Icons.delete, color: Colors.pinkAccent),
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
                  widget.onDelete();
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
          location: LatLng(widget.memory.latitude, widget.memory.longitude),
          existingMemory: widget.memory,
          onSave: (updatedMemory) {
            Navigator.pop(context);
            Navigator.pop(context);

            if (widget.onUpdate != null) {
              widget.onUpdate!(updatedMemory);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recuerdo actualizado correctamente'),
                backgroundColor: pinkPrimary,
                duration: Duration(seconds: 2),
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
