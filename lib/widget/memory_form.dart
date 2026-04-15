import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import '../services/image_picker_service.dart';
import '../services/MemoryService.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/coordinate_input_screen.dart';
import '../providers/category_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:video_player/video_player.dart';
import '../constants/category_icons.dart';

/// Formulario principal para crear y editar los recuerdos
/// Maneja la subida de foto/video, PIN para carpetas y obtiene coordenadas GPS de los recuerdos
class MemoryForm extends StatefulWidget {
  final LatLng location;
  final Memory? existingMemory;
  final Function(Memory) onSave;
  final Function() onCancel;
  final Function()? onCategoriesChanged;

  const MemoryForm({
    super.key,
    required this.location,
    this.existingMemory,
    required this.onSave,
    required this.onCancel,
    this.onCategoriesChanged,
  });

  @override
  State<MemoryForm> createState() => _MemoryFormState();
}

class _MemoryFormState extends State<MemoryForm> {
  // Controladores para los campos del formulario
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final ImagePickerService _pickerService = ImagePickerService();
  final MemoryService _memoryService = MemoryService();
  final TextEditingController _customCategoryController =
      TextEditingController();
  bool _protectNewCategory = false;
  String _newCategoryPin = '';
  String _confirmNewCategoryPin = '';
  TextEditingController _pinController = TextEditingController();
  TextEditingController _confirmPinController = TextEditingController();
  String? _selectedAsset;
  bool _isLoadingMedia = false;
  bool _isSaving = false;
  Uint8List? _selectedBytes;
  bool _isVideo = false;
  String _selectedCategory = '';
  bool _isCustomCategory = false;
  double? _photoLatitude;
  double? _photoLongitude;
  bool _usePhotoLocation = false;
  late LatLng _currentFormLocation;
  List<String> _categories = [];

  final List<String> _availableAssets = [
    'assets/images/gato.jpg',
    'assets/images/perro.jpg',
    'assets/images/memory3.jpg',
    'assets/images/memory4.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _currentFormLocation = widget.location;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCategories();
      }
    });

    // Inicializar controladores de PIN
    _pinController = TextEditingController();
    _confirmPinController = TextEditingController();
  }

  /// Inicializa los campos del formulario si se está editando un recuerdo, o carga lo que hay por defecto si es nuevo
  void _initializeFormData() {
    if (widget.existingMemory != null) {
      _titleController.text = widget.existingMemory!.title;
      _descriptionController.text = widget.existingMemory!.description;
      _dateController.text = widget.existingMemory!.date;
      _selectedAsset = widget.existingMemory!.imageAsset;
      _selectedCategory = widget.existingMemory!.category;
      _isCustomCategory = false;

      if (_selectedAsset != null && _selectedAsset!.endsWith('.mp4')) {
        _isVideo = true;
      }
    } else {
      _dateController.text = DateTime.now().toString().split(' ')[0];
      _selectedAsset = _availableAssets[0];
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    }
  }

  /// Carga las categorías disponibles desde el Provider con "General" la primera por defecto
  Future<void> _loadCategories() async {
    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.loadCategories();

      setState(() {
        _categories = List.from(categoryProvider.categories);
        _initializeFormData();
      });
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
      setState(() {
        _categories = ['General'];
        _initializeFormData();
      });
    }
  }

  /// Despliega el calendario para seleccionar la fecha del recuerdo
  Future<void> _selectDate(BuildContext context) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: isDarkMode
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: pinkPrimary,
                    onPrimary: Colors.white,
                    surface: backgroundDark,
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: pinkPrimary,
                    onPrimary: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = picked.toString().split(' ')[0];
      });
    }
  }

  /// Muestra el menú inferior (BottomSheet) con las opciones para subir contenido multimedia
  void _pickImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Añadir Multimedia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? textDarkMode : pinkDark,
                  ),
                ),
                const SizedBox(height: 20),

                // seccion de fotos solo en movil, en web se suben como archivos normales
                if (!kIsWeb) ...[
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: pinkPrimary),
                    title: Text('Tomar foto',
                        style: TextStyle(
                            color: isDarkMode ? textDarkMode : Colors.black87)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImageFromCamera();
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.photo_library, color: pinkPrimary),
                    title: Text('Galería de fotos',
                        style: TextStyle(
                            color: isDarkMode ? textDarkMode : Colors.black87)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImageFromGallery();
                    },
                  ),
                ],

                const Divider(),

                // seccion de videos solo en movil, en web se suben como archivos normales
                if (!kIsWeb) ...[
                  ListTile(
                    leading: const Icon(Icons.videocam, color: pinkPrimary),
                    title: Text('Grabar video (Max 20s)',
                        style: TextStyle(
                            color: isDarkMode ? textDarkMode : Colors.black87)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickVideoFromCamera();
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.video_library, color: pinkPrimary),
                    title: Text('Galería de videos',
                        style: TextStyle(
                            color: isDarkMode ? textDarkMode : Colors.black87)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickVideoFromGallery();
                    },
                  ),
                ],

                // subir foto en web
                if (kIsWeb) ...[
                  ListTile(
                    leading:
                        const Icon(Icons.photo_library, color: pinkPrimary),
                    title: Text('Subir foto',
                        style: TextStyle(
                            color: isDarkMode ? textDarkMode : Colors.black87)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImageFromGallery();
                    },
                  ),
                  // subir video en web
                  ListTile(
                    leading:
                        const Icon(Icons.video_library, color: pinkPrimary),
                    title: Text('Subir video',
                        style: TextStyle(
                            color: isDarkMode ? textDarkMode : Colors.black87)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickVideoForWeb();
                    },
                  ),
                ],

                const Divider(),

                // imagenes predeterminadas
                ListTile(
                  leading: const Icon(Icons.image_search, color: Colors.grey),
                  title: Text('Imágenes predeterminadas',
                      style: TextStyle(
                          color: isDarkMode ? textDarkMode : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    _selectAsset();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Método que abre la cámara para tomar una foto y extrae su ubicación actual si el usuario lo permite
  Future<void> _pickImageFromCamera() async {
    setState(() => _isLoadingMedia = true);
    try {
      final path = await _pickerService.pickImageFromCamera();
      if (path != null) {
        final bytes = await File(path).readAsBytes();

        try {
          await getCurrentLocation();
        } catch (e) {
          debugPrint('Error obteniendo ubicación: $e');
        }

        setState(() {
          _selectedAsset = path;
          _selectedBytes = bytes;
          _isVideo = false; // Es foto
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMedia = false);
      }
    }
  }

  /// Método que solicita y verifica permisos de geolocalización actual del dispositivo
  Future<Position> determinePosition() async {
    LocationPermission permission;

    // Verificar permisos de ubicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permisos de ubicación denegados');
      }
    }

    // verificar si la ubicación está activada
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      throw Exception('Ubicación desactivada');
    }

    // obtener la posición actual
    return await Geolocator.getCurrentPosition();
  }

  /// obitiene la ubicación actual y la guarda en el estado local del formulario
  Future<void> getCurrentLocation() async {
    try {
      Position position = await determinePosition();
      debugPrint('Latitud: ${position.latitude}');
      debugPrint('Longitud: ${position.longitude}');

      // guarda la ubicación obtenida
      setState(() {
        _photoLatitude = position.latitude;
        _photoLongitude = position.longitude;
        _usePhotoLocation = true;
      });
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
      setState(() {
        _usePhotoLocation = false;
      });
    }
  }

  /// Abre la galería, selecciona una imagen y la guarda para subir o mostrar
  Future<void> _pickImageFromGallery() async {
    setState(() => _isLoadingMedia = true);

    try {
      if (kIsWeb) {
        // logica para web: obtenemos los bytes y creamos una URL de datos para mostrar la imagen (ya que no hay path en web)
        final bytes = await _pickerService.pickImageAsBytes();
        if (bytes != null && bytes.isNotEmpty) {
          setState(() {
            // crea una URL de datos (Base64) para poder mostrar la imagen
            _selectedAsset = 'data:image/jpeg;base64,${base64.encode(bytes)}';
            _selectedBytes = bytes;
            _isVideo = false;
          });
        }
      } else {
        // logica para móvil: obtenemos el path del archivo y leemos los bytes desde el disco para mostrar la imagen
        final path = await _pickerService.pickImageFromGallery();
        if (path != null) {
          // lee el archivo desde el disco y lo convierte a bytes para poder subirlo después
          final bytes = await File(path).readAsBytes();
          setState(() {
            _selectedAsset = path;
            _selectedBytes = bytes;
            _isVideo = false; // es foto
          });
        }
      }
    } catch (e) {
      if (!mounted) {
        return; // Evita mostrar el SnackBar si el widget ya no está montado
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMedia = false);
      }
    }
  }

  /// Método que abre la cámara para grabar un video
  Future<void> _pickVideoFromCamera() async {
    setState(() => _isLoadingMedia = true);
    try {
      final path = await _pickerService.pickVideoFromCamera();
      if (path != null) {
        final bytes = await _pickerService.getBytesFromPath(path);
        setState(() {
          _selectedAsset = path;
          _selectedBytes = bytes;
          _isVideo = true;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al grabar video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMedia = false);
      }
    }
  }

  /// Método que abre la galería para seleccionar un video
  Future<void> _pickVideoFromGallery() async {
    setState(() => _isLoadingMedia = true);
    try {
      final path = await _pickerService.pickVideoFromGallery();
      if (path != null) {
        final bytes = await _pickerService.getBytesFromPath(path);
        setState(() {
          _selectedAsset = path;
          _selectedBytes = bytes;
          _isVideo = true;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar el video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMedia = false);
      }
    }
  }

  /// Método que selecciona un video compatible con la web
  Future<void> _pickVideoForWeb() async {
    setState(() => _isLoadingMedia = true);
    try {
      final bytes = await _pickerService.pickVideoBytesForWeb();
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          // no tenemos un path real, así que usamos un placeholder y guardamos los bytes para subirlos después
          _selectedAsset = 'web_video_upload.mp4';
          _selectedBytes = bytes;
          _isVideo = true;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMedia = false);
      }
    }
  }

  /// Abre un modal con las imágenes por defecto
  void _selectAsset() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleccionar imagen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? textDarkMode : pinkDark,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _availableAssets.length,
                  itemBuilder: (context, index) {
                    final asset = _availableAssets[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAsset = asset;
                          _selectedBytes = null; // Es un asset, no bytes
                          _isVideo = false;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedAsset == asset
                                ? pinkPrimary
                                : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey
                                  .withValues(alpha: isDarkMode ? 0.1 : 0.3),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            asset,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: isDarkMode ? cardLight : pinkLighter,
                              child: const Icon(Icons.error, color: pinkDark),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Método que muestra la imagen o video seleccionado, o un placeholder si no hay ninguno
  Widget _showSelectedImage() {
    if (_isLoadingMedia) {
      return const Center(child: CircularProgressIndicator(color: pinkPrimary));
    }

    if (_selectedAsset == null || _selectedAsset!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: pinkPrimary, size: 40),
            SizedBox(height: 5),
            Text('Añadir foto o video', style: TextStyle(color: pinkPrimary)),
          ],
        ),
      );
    }

    // si es un video, se ve un placeholder de que se ha seleccionado un video
    if (_isVideo) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
              SizedBox(height: 10),
              Text('Video seleccionado', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    // si es un asset, se muestra desde la ruta (no se usa bytes)
    if (_selectedAsset!.startsWith('assets/')) {
      return Image.asset(
        _selectedAsset!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: pinkLighter,
          child: const Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        ),
      );
    }

    // si es una imagen web que viene como Base64 (data URL)
    if (_selectedAsset!.startsWith('data:image')) {
      try {
        final bytes = base64.decode(_selectedAsset!.split(',')[1]);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return Container(
          color: pinkLighter,
          child: const Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        );
      }
    }

    // si es un path local (móvil), se muestra desde el archivo (no se usa bytes)
    if (_selectedAsset!.startsWith('/') || _selectedAsset!.contains('file:')) {
      return Image.file(
        File(_selectedAsset!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: pinkLighter,
          child: const Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        ),
      );
    }

    // si es una imagen web que viene como URL, se muestra desde la red (no se usa bytes)
    if (_selectedAsset!.startsWith('http')) {
      return Image.network(
        _selectedAsset!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: pinkPrimary,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: pinkLighter,
          child: const Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        ),
      );
    }

    // por defecto
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: pinkPrimary, size: 40),
          SizedBox(height: 5),
          Text('Imagen no compatible', style: TextStyle(color: pinkPrimary)),
        ],
      ),
    );
  }

  /// Método que guarda los datos del formulario en Supabase y actualiza los metadatos de las carpetas protegidas
  Future<void> _saveMemory() async {
    if (_isSaving) {
      return;
    }

    // capturamos ScaffoldMessenger y CategoryProvider para evitar problemas de contexto dentro de los async/await
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final date = _dateController.text.trim();

    // validaciones de campos obligatorios
    if (title.isEmpty || date.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa los campos obligatorios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // validación para videos: duración máxima de 20 segundos en móvil o peso máximo de 15 MB en web
    if (_isVideo) {
      bool isVideoValid = true;
      String errorMessage = '';

      setState(() => _isSaving = true);

      if (!kIsWeb && _selectedAsset != null) {
        // validación para movil/app de 20 segundos
        try {
          final controller = VideoPlayerController.file(File(_selectedAsset!));
          await controller.initialize();
          if (controller.value.duration.inSeconds > 20) {
            isVideoValid = false;
            errorMessage =
                'El video dura más de 20 segundos. Por favor, selecciona uno más corto.';
          }
          await controller.dispose();
        } catch (e) {
          debugPrint('Error validando duración en móvil: $e');
        }
      } else if (kIsWeb && _selectedBytes != null) {
        // validación para web 15 mb (en web no se puede validar duración)
        const int maxSizeInBytes = 15 * 1024 * 1024;

        if (_selectedBytes!.length > maxSizeInBytes) {
          isVideoValid = false;
          errorMessage =
              'El video es muy pesado (máximo 15 MB / 20 seg). Por favor, sube uno más corto.';
        }
      }

      // si hubo algúna validación fallida, mostramos el error y detenemos el guardado
      if (!isVideoValid) {
        setState(() => _isSaving = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() => _isSaving = false);
    }

    // logica para saber la categoría del recuerdo, si es personalizada o existente, y manejar el PIN si tiene
    String finalCategory = _selectedCategory;
    bool isProtected = false;
    String? passwordHash;

    if (_isCustomCategory) {
      final customText = _customCategoryController.text.trim();
      if (customText.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content:
                Text('Por favor, escribe un nombre para la nueva categoría'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      finalCategory = customText;
      isProtected = false;
      passwordHash = null;

      // crear nueva categoría personalizada
      try {
        await categoryProvider.createCategory(finalCategory);

        // si el usuario quiere proteger la categoría, guardar el PIN
        if (_protectNewCategory) {
          if (_newCategoryPin.length != 6) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('El PIN debe tener 6 dígitos'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          // validamos que el PIN y su confirmación coincidan antes de guardar
          if (_newCategoryPin != _confirmNewCategoryPin) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Los PINs no coinciden'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // guardamos el PIN guardado como un hash para seguridad
          final hash = sha256.convert(utf8.encode(_newCategoryPin)).toString();
          await categoryProvider.setCategoryPassword(finalCategory, hash);
          debugPrint('Categoría "$finalCategory" protegida con PIN');
        }

        await _loadCategories();
        widget.onCategoriesChanged?.call();
      } catch (e) {
        debugPrint('Error creando categoría: $e');
        categoryProvider.addCategoryLocally(finalCategory);
      }
    }

    // obtener la protección configurada por categoría
    isProtected = categoryProvider.isCategoryProtected(finalCategory);
    passwordHash = categoryProvider.getPasswordHash(finalCategory);

    setState(() => _isSaving = true);

    try {
      // determinar la ubicación a guardar
      double latitude, longitude;

      bool ubicacionModificada =
          _currentFormLocation.latitude != widget.location.latitude ||
              _currentFormLocation.longitude != widget.location.longitude;

      if (ubicacionModificada) {
        latitude = _currentFormLocation.latitude;
        longitude = _currentFormLocation.longitude;
        debugPrint('Usando ubicación manual: $latitude, $longitude');
      } else if (_usePhotoLocation &&
          _photoLatitude != null &&
          _photoLongitude != null) {
        latitude = _photoLatitude!;
        longitude = _photoLongitude!;
        debugPrint('Usando ubicación actual: $latitude, $longitude');
      } else {
        latitude = _currentFormLocation.latitude;
        longitude = _currentFormLocation.longitude;
        debugPrint('Usando ubicación del formulario: $latitude, $longitude');
      }

      // crear el objeto Memory con la categoría correcta
      Memory memoryToSave = Memory(
        id: widget.existingMemory?.id ?? '',
        title: title,
        description: description,
        date: date,
        location: {
          'latitude': latitude,
          'longitude': longitude,
        },
        imageAsset: _selectedAsset,
        category: finalCategory,
        hasPassword: isProtected,
        passwordHash: passwordHash,
        creatorId: widget.existingMemory?.creatorId,
        creatorEmail: widget.existingMemory?.creatorEmail,
        sharedRoles: widget.existingMemory?.sharedRoles ?? {},
        sharedWith: widget.existingMemory?.sharedWith ?? [],
      );

      Memory finalMemory;

      // lógica de guardado según el tipo de archivo
      if (_selectedBytes != null && _selectedBytes!.isNotEmpty) {
        if (_isVideo) {
          debugPrint('Subiendo video...');
          finalMemory = await _memoryService.saveMemoryWithVideo(
            memory: memoryToSave,
            videoBytes: _selectedBytes!,
          );
        } else {
          debugPrint('Subiendo imagen...');
          final savedId = await _memoryService.saveMemoryWithImage(
            memory: memoryToSave,
            imageBytes: _selectedBytes!,
          );
          final memories = await _memoryService.getMemories();
          finalMemory = memories.firstWhere((m) => m.id == savedId);
        }
      } else {
        await _memoryService.saveMemory(memoryToSave);
        finalMemory = memoryToSave;
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Recuerdo guardado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSave(finalMemory);
    } catch (e) {
      debugPrint('Error guardando recuerdo: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Dialog(
      backgroundColor: isDarkMode ? backgroundDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existingMemory == null
                      ? 'Crear nuevo recuerdo'
                      : 'Editar recuerdo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? textDarkMode : pinkDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Campo de título
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    color: isDarkMode ? textDarkMode : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Título *',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : pinkLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : pinkLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: pinkPrimary, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.title, color: pinkPrimary),
                    fillColor: isDarkMode ? cardDark : Colors.white,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 15),

                // Campo de descripción
                TextField(
                  controller: _descriptionController,
                  style: TextStyle(
                    color: isDarkMode ? textDarkMode : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : pinkLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : pinkLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: pinkPrimary, width: 2),
                    ),
                    prefixIcon:
                        const Icon(Icons.description, color: pinkPrimary),
                    fillColor: isDarkMode ? cardDark : Colors.white,
                    filled: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 15),

                // Campo de fecha
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dateController,
                      style: TextStyle(
                        color: isDarkMode ? textDarkMode : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Fecha *',
                        labelStyle: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[700],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDarkMode ? Colors.grey[700]! : pinkLight,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDarkMode ? Colors.grey[700]! : pinkLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: pinkPrimary, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today,
                            color: pinkPrimary),
                        fillColor: isDarkMode ? cardDark : Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Campo de categoría con opción de PIN
                if (_isCustomCategory)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customCategoryController,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 15,
                                ),
                                labelText: 'Escribe la nueva categoría',
                                hintText: 'Ej: Deportes, Conciertos...',
                                labelStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey[700]!
                                        : pinkLight,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey[700]!
                                        : pinkLight,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: pinkPrimary,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.edit,
                                  color: pinkPrimary,
                                ),
                                filled: true,
                                fillColor: isDarkMode ? cardDark : Colors.white,
                              ),
                              style: TextStyle(
                                color:
                                    isDarkMode ? textDarkMode : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón para cancelar y volver al dropdown
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: isDarkMode ? cardDark : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: IconButton(
                              iconSize: 30,
                              icon: const Icon(Icons.close, color: Colors.grey),
                              tooltip: 'Volver a la lista',
                              onPressed: () {
                                setState(() {
                                  _isCustomCategory = false;
                                  _protectNewCategory = false;
                                  _newCategoryPin = '';
                                  _confirmNewCategoryPin = '';
                                  if (_categories.isNotEmpty) {
                                    _selectedCategory = _categories.first;
                                  } else {
                                    _selectedCategory = 'General';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // Checkbox para proteger con PIN
                      Row(
                        children: [
                          Checkbox(
                            value: _protectNewCategory,
                            onChanged: (value) {
                              setState(() {
                                _protectNewCategory = value ?? false;
                                if (!_protectNewCategory) {
                                  _newCategoryPin = '';
                                  _confirmNewCategoryPin = '';
                                  _pinController.clear();
                                  _confirmPinController.clear();
                                }
                              });
                            },
                            activeColor: pinkPrimary,
                          ),
                          Expanded(
                            child: Text(
                              'Proteger esta carpeta con PIN',
                              style: TextStyle(
                                color:
                                    isDarkMode ? textDarkMode : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Campos de PIN (solo si el checkbox está activo)
                      if (_protectNewCategory) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 24, letterSpacing: 8),
                          decoration: InputDecoration(
                            hintText: 'PIN de 6 dígitos',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: pinkPrimary,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _newCategoryPin = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _confirmPinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 24, letterSpacing: 8),
                          decoration: InputDecoration(
                            hintText: 'Confirmar PIN',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: pinkPrimary,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _confirmNewCategoryPin = value);
                          },
                        ),
                      ],
                    ],
                  )
                else
                  // Dropdown de categorías existentes
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDarkMode ? Colors.grey[700]! : pinkLight,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _categories.contains(_selectedCategory)
                            ? _selectedCategory
                            : (_categories.isNotEmpty
                                ? _categories.first
                                : null),
                        isExpanded: true,
                        itemHeight: 60,
                        dropdownColor: isDarkMode ? cardDark : Colors.white,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: pinkPrimary, size: 30),
                        items: [
                          // Se muestran las opciones del dropdown a partir de las categorías que hay
                          ..._categories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Row(
                                children: [
                                  Icon(CategoryIcons.getIcon(category), color: pinkPrimary, size: 24),
                                  const SizedBox(width: 15),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDarkMode
                                          ? textDarkMode
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          // opción para crear una nueva categoría personalizada
                          const DropdownMenuItem<String>(
                            value:
                                'custom_option_marker', // Valor identificador único
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline,
                                    color: pinkPrimary, size: 24),
                                SizedBox(width: 15),
                                Text(
                                  'Nueva categoría...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: pinkPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue == 'custom_option_marker') {
                            setState(() {
                              _isCustomCategory = true;
                              _customCategoryController.clear();
                            });
                          } else if (newValue != null) {
                            // Si seleccionan una que habia, actualizamos valor
                            setState(() => _selectedCategory = newValue);
                          }
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Campo de imagen/video
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Imagen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? textDarkMode : pinkDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImageOptions,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? cardDark.withValues(alpha: 0.5)
                              : pinkLighter.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pinkPrimary,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey
                                  .withValues(alpha: isDarkMode ? 0.1 : 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _showSelectedImage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Presiona para cambiar la imagen',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // Campo de ubicación con acceso al mapa para seleccionar coordenadas
                GestureDetector(
                  onTap: () async {
                    final LatLng? selectedLocation =
                        await Navigator.of(context).push<LatLng>(
                      MaterialPageRoute(
                        builder: (context) => const CoordinateInputScreen(),
                      ),
                    );

                    // Evitar errores si el usuario navega fuera de la pantalla
                    if (!context.mounted) {
                      return;
                    }

                    // Si selecciona una ubicación, actualiza la ubicación actual
                    if (selectedLocation != null) {
                      setState(() {
                        _currentFormLocation = selectedLocation;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ubicación actualizada'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? cardDark
                          : pinkLighter.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDarkMode ? Colors.grey[700]! : pinkPrimary,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: pinkPrimary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ubicación (toca para cambiar en el mapa)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_currentFormLocation.latitude.toStringAsFixed(6)}, ${_currentFormLocation.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: pinkPrimary,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new,
                            color: pinkPrimary, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // Botones para guardar o cancelar
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : widget.onCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveMemory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isSaving ? Colors.grey : pinkPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          shadowColor: pinkPrimary.withValues(alpha: 0.4),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Guardar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Limpiar los controladores
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _customCategoryController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
