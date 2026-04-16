import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import 'memory_form.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/category_icons.dart';

// Pantalla de detalle que muestra la informacion completa de un recuerdo
class MemoryDetailScreen extends StatefulWidget {
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
  // Controladores para el reproductor de video
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  // Indica si el archivo es un video
  bool _isVideo = false;
  
  // Indica si hubo error al cargar el video
  bool _isInitVideoError = false;

  @override
  void initState() {
    super.initState();
    _checkMediaType(); // Verificar si es imagen o video al iniciar
  }

  @override
  void didUpdateWidget(MemoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la url cambia, se reinicia el controlador
    if (widget.memory.imageAsset != oldWidget.memory.imageAsset) {
      _disposeControllers();
      _checkMediaType();
    }
  }

  @override
  void dispose() {
    _disposeControllers(); // Limpiar recursos
    super.dispose();
  }

  // Limpiar los controladores de video
  void _disposeControllers() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  // Verificar si el usuario tiene permisos de edicion
  bool _canEdit() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    
    // Si es el creador, puede editar
    if (widget.memory.creatorId == null ||
        widget.memory.creatorId == currentUser?.id) {
      return true;
    }
    
    // Si es admin o editor en recuerdo compartido, puede editar
    final role = widget.memory.sharedRoles?[currentUser?.email];
    if (role == 'admin' || role == 'editor') {
      return true;
    } else {
      return false;
    }
  }

  // Verificar si el usuario tiene permisos para eliminar
  bool _canDelete() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    
    // Solo el creador o admin pueden eliminar
    if (widget.memory.creatorId == null ||
        widget.memory.creatorId == currentUser?.id) {
      return true;
    }
    
    final role = widget.memory.sharedRoles?[currentUser?.email];
    if (role == 'admin') {
      return true;
    } else {
      return false;
    }
  }

  // Verificar si es video o imagen
  void _checkMediaType() {
    final path = widget.memory.imageAsset?.trim();
    if (path == null || path.isEmpty) {
      return;
    }

    // Detectar si es .mp4 y no es asset interno
    if (!path.startsWith('assets/') && path.toLowerCase().contains('.mp4')) {
      setState(() {
        _isVideo = true;
      });
      _initializePlayer(path);
    } else {
      setState(() {
        _isVideo = false;
      });
    }
  }

  // Inicializar el reproductor de video
  Future<void> _initializePlayer(String path) async {
    try {
      // Cargar video desde URL o archivo local
      if (kIsWeb || path.startsWith('http')) {
        _videoPlayerController =
            VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        _videoPlayerController = VideoPlayerController.file(File(path));
      }
      
      await _videoPlayerController!.initialize();
      
      // Configurar reproductor Chewie
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) => const Center(
            child: Text('Error video', style: TextStyle(color: Colors.white))),
      );
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error video: $e");
      if (mounted) {
        setState(() {
          _isInitVideoError = true;
        });
      }
    }
  }

  // Compartir recuerdo
  Future<void> _shareMemory() async {
    // Enlace de Google Maps con las coordenadas
    final String googleMapsLink =
        'https://www.google.com/maps/search/?api=1&query=${widget.memory.latitude},${widget.memory.longitude}';

    // Texto a compartir
    final String shareText = '''
NaYeKa Memories - Recuerdo compartido

Titulo: ${widget.memory.title}
Descripcion: ${widget.memory.description}
Fecha: ${widget.memory.date.split('T')[0]}

Ver ubicacion en Maps: $googleMapsLink

Creado con NaYeKa Memories: 
https://nayeka-memories.com
''';

    final mediaPath = widget.memory.imageAsset?.trim();

    try {
      // Si no hay imagen ni video, solo texto
      if (mediaPath == null || mediaPath.isEmpty) {
        await SharePlus.instance.share(ShareParams(text: shareText));
        return;
      }

      // Determinar el tipo de media
      String mediaIcon;
      if (widget.memory.isVideo) {
        mediaIcon = 'Video';
      } else {
        mediaIcon = 'Imagen';
      }

      // Para web solo se puede compartir texto
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(text: '$shareText\n\n$mediaIcon: $mediaPath'),
        );
        return;
      }

      // Para movil con URL (descargar y compartir archivo)
      if (mediaPath.startsWith('http')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparando archivo...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            duration: Duration(seconds: 1),
            padding: EdgeInsets.all(20),
          ),
        );

        final response = await http.get(Uri.parse(mediaPath));
        final tempDir = await getTemporaryDirectory();
        
        // Extension segun tipo de archivo
        String extension;
        if (widget.memory.isVideo) {
          extension = '.mp4';
        } else {
          extension = '.jpg';
        }
        
        final tempFile = File(
            '${tempDir.path}/recuerdo_${DateTime.now().millisecondsSinceEpoch}$extension');

        await tempFile.writeAsBytes(response.bodyBytes);
        await SharePlus.instance.share(
          ShareParams(text: shareText, files: [XFile(tempFile.path)]),
        );
      } 
      // Para movil con archivo local
      else if (!mediaPath.startsWith('assets/')) {
        await SharePlus.instance.share(
          ShareParams(text: shareText, files: [XFile(mediaPath)]),
        );
      } 
      // Para assets internos (solo texto)
      else {
        await SharePlus.instance.share(ShareParams(text: shareText));
      }
    } catch (e) {
      debugPrint('Error al compartir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e', style: const TextStyle(fontSize: 18)),
            backgroundColor: Colors.red,
            padding: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  // Funcion auxiliar para obtener el color segun el tema
  Color _getColor(Color lightColor, Color darkColor, bool isDarkMode) {
    if (isDarkMode) {
      return darkColor;
    } else {
      return lightColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _getColor(Colors.white, backgroundDark, isDarkMode),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: pinkPrimary.withValues(alpha: isDarkMode ? 0.1 : 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                _buildHeader(isDarkMode),
                _buildContent(isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  // Encabezado con titulo y boton cerrar
  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: _getColor(pinkPrimary, pinkDark, isDarkMode),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detalles del Recuerdo',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text('Un lugar especial para ti',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
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

  // Contenido principal
  Widget _buildContent(bool isDarkMode) {
    final showActions = _canEdit() || _canDelete();

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
          if (showActions) ...[
            _buildActionButtons(isDarkMode),
            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }

  // Mostrar imagen o video
  Widget _buildImage(bool isDarkMode) {
    final path = widget.memory.imageAsset?.trim();

    // Si no hay imagen, mostrar error
    if (path == null || path.isEmpty) {
      return Container(
        height: 250,
        color: _getColor(pinkLighter, cardDark, isDarkMode),
        alignment: Alignment.center,
        child: const Icon(Icons.error, color: pinkPrimary, size: 50),
      );
    }

    // Seccion de video
    if (_isVideo) {
      if (_isInitVideoError) {
        return Container(
          height: 250,
          color: _getColor(pinkLighter, cardDark, isDarkMode),
          alignment: Alignment.center,
          child: const Icon(Icons.error, color: pinkPrimary, size: 50),
        );
      }
      if (_chewieController != null && _videoPlayerController!.value.isInitialized) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: Chewie(controller: _chewieController!),
          ),
        );
      }
      return Container(
        height: 250,
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: CircularProgressIndicator(color: pinkPrimary)),
      );
    }

    // Seccion de imagen
    Widget imageWidget;
    
    if (path.startsWith('assets/')) {
      // Imagen desde assets internos
      imageWidget = Image.asset(path, fit: BoxFit.contain);
    } else if (kIsWeb || path.startsWith('http')) {
      // Imagen desde URL
      imageWidget = Image.network(
        path,
        key: ValueKey(path),
        fit: BoxFit.contain,
        cacheWidth: 1200,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator(color: pinkPrimary)));
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: 250,
          color: _getColor(pinkLighter, cardDark, isDarkMode),
          alignment: Alignment.center,
          child: const Icon(Icons.error, color: pinkPrimary, size: 50),
        ),
      );
    } else {
      // Imagen desde archivo local
      imageWidget = Image.file(
        File(path),
        fit: BoxFit.contain,
        cacheWidth: 1200,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 250,
          color: _getColor(pinkLighter, cardDark, isDarkMode),
          alignment: Alignment.center,
          child: const Icon(Icons.error, color: pinkPrimary, size: 50),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _getColor(Colors.grey[100]!, Colors.black26, isDarkMode),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: imageWidget),
    );
  }

  // Mostrar titulo y categoria
  Widget _buildTitle(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta de categoria
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pinkPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: pinkPrimary.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CategoryIcons.getIcon(widget.memory.category), size: 16, color: pinkPrimary),
              const SizedBox(width: 6),
              Text(widget.memory.category,
                  style: const TextStyle(color: pinkPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Titulo del recuerdo
        Text(
          widget.memory.title,
          style: TextStyle(
            color: _getColor(pinkDark, textDarkMode, isDarkMode),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // Mostrar fecha
  Widget _buildDate(bool isDarkMode) {
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: pinkPrimary, size: 18),
        const SizedBox(width: 8),
        Text(
          widget.memory.date,
          style: TextStyle(
            color: _getColor(pinkDark.withValues(alpha: 0.8), Colors.grey[400]!, isDarkMode),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // Mostrar descripcion
  Widget _buildDescription(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Descripcion',
            style: TextStyle(
              color: _getColor(pinkDark, textDarkMode, isDarkMode),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 10),
        Text(
          widget.memory.description,
          style: TextStyle(
            color: _getColor(backgroundDark, Colors.grey[300]!, isDarkMode),
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // Mostrar informacion de ubicacion
  Widget _buildLocationInfo(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getColor(pinkLighter, cardDark, isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor(pinkLight.withValues(alpha: 0.3), Colors.grey[700]!, isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titulo de ubicacion
          Row(
            children: [
              const Icon(Icons.location_on, color: pinkPrimary, size: 24),
              const SizedBox(width: 10),
              Text('Ubicacion exacta',
                  style: TextStyle(
                    color: _getColor(pinkDark, textDarkMode, isDarkMode),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 15),
          // Latitud
          Row(
            children: [
              const Icon(Icons.north, color: pinkPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Latitud: ${widget.memory.latitude.toStringAsFixed(6)}',
                    style: TextStyle(color: _getColor(pinkDark, Colors.grey[300]!, isDarkMode), fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Longitud
          Row(
            children: [
              const Icon(Icons.east, color: pinkPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Longitud: ${widget.memory.longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: _getColor(pinkDark, Colors.grey[300]!, isDarkMode), fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Botones de accion
  Widget _buildActionButtons(bool isDarkMode) {
    return Column(
      children: [
        // Boton compartir (solo si tiene permisos de edicion)
        if (_canEdit()) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareMemory,
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkLighter,
                foregroundColor: pinkPrimary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 3,
              ),
              icon: const Icon(Icons.share, size: 28),
              label: const Text('Compartir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 15),
          // Boton editar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEditOptions(isDarkMode),
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkPrimary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 5,
              ),
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text('Editar recuerdo',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 15),
        ],
        // Boton eliminar (solo si tiene permisos)
        if (_canDelete())
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onDelete,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getColor(Colors.white, cardDark, isDarkMode),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: pinkPrimary, width: 2),
                ),
              ),
              icon: const Icon(Icons.delete, color: pinkPrimary),
              label: const Text('Eliminar',
                  style: TextStyle(color: pinkPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  // Mostrar opciones de edicion
  void _showEditOptions(bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _getColor(Colors.white, backgroundDark, isDarkMode),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titulo
              Text('¿Que deseas editar?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: _getColor(pinkDark, textDarkMode, isDarkMode))),
              const SizedBox(height: 20),
              // Opcion: editar solo ubicacion
              ListTile(
                leading: const Icon(Icons.edit_location, color: pinkPrimary),
                title: Text('Editar solo ubicacion',
                    style: TextStyle(color: isDarkMode ? textDarkMode : Colors.black87)),
                subtitle: Text('Cambia las coordenadas del recuerdo',
                    style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                tileColor: isDarkMode ? cardDark.withValues(alpha: 0.5) : null,
                onTap: () {
                  Navigator.pop(context);
                  widget.onEdit();
                },
              ),
              Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
              // Opcion: editar todos los datos
              ListTile(
                leading: const Icon(Icons.edit_note, color: pinkPrimary),
                title: Text('Editar todos los datos',
                    style: TextStyle(color: isDarkMode ? textDarkMode : Colors.black87)),
                subtitle: Text('Titulo, descripcion, fecha, imagen y ubicacion',
                    style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                tileColor: isDarkMode ? cardDark.withValues(alpha: 0.5) : null,
                onTap: () {
                  Navigator.pop(context);
                  _navigateToFullEditForm(context);
                },
              ),
              // Opcion: eliminar (solo si tiene permisos)
              if (_canDelete()) ...[
                Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.pinkAccent),
                  title: Text('Eliminar recuerdo',
                      style: TextStyle(color: isDarkMode ? textDarkMode : Colors.black87)),
                  subtitle: Text('Elimina permanentemente este recuerdo',
                      style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                  tileColor: isDarkMode ? cardDark.withValues(alpha: 0.5) : null,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Navegar al formulario de edicion completa
  void _navigateToFullEditForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return MemoryForm(
          location: LatLng(widget.memory.latitude, widget.memory.longitude),
          existingMemory: widget.memory,
          onSave: (updatedMemory) {
            Navigator.pop(context); // Cerrar dialogo
            Navigator.pop(context); // Cerrar modal de edicion
            if (widget.onUpdate != null) widget.onUpdate!(updatedMemory);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recuerdo actualizado correctamente'),
                backgroundColor: pinkPrimary,
                duration: Duration(seconds: 2),
              ),
            );
          },
          onCancel: () => Navigator.pop(context),
        );
      },
    );
  }
}