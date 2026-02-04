import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import '../services/ImagePickerService.dart';
import '../services/MemoryService.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class MemoryForm extends StatefulWidget {
  final LatLng location;
  final Memory? existingMemory;
  final Function(Memory) onSave;
  final Function() onCancel;

  const MemoryForm({
    super.key,
    required this.location,
    this.existingMemory,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<MemoryForm> createState() => _MemoryFormState();
}

class _MemoryFormState extends State<MemoryForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final ImagePickerService _pickerService = ImagePickerService();
  final MemoryService _memoryService = MemoryService();

  String? _selectedAsset;
  bool _isLoadingImage = false;
  bool _isSaving = false;
  Uint8List? _selectedImageBytes;

  final List<String> _availableAssets = [
    'assets/images/gato.jpg',
    'assets/images/perro.jpg',
    'assets/images/memory3.jpg',
    'assets/images/memory4.jpg',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingMemory != null) {
      _titleController.text = widget.existingMemory!.title;
      _descriptionController.text = widget.existingMemory!.description;
      _dateController.text = widget.existingMemory!.date;
      _selectedAsset = widget.existingMemory!.imageAsset;
    } else {
      _dateController.text = DateTime.now().toString().split(' ')[0];
      _selectedAsset = _availableAssets[0];
    }
  }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleccionar origen de imagen',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: isDarkMode ? textDarkMode : pinkDark,
                ),
              ),
              const SizedBox(height: 20),
              
              // Opción de cámara (solo mostrar si no es web)
              if (!kIsWeb) ...[
                ListTile(
                  leading: Icon(Icons.camera_alt, color: pinkPrimary),
                  title: Text('Sacar una foto', style: TextStyle(
                    color: isDarkMode ? textDarkMode : Colors.black87,
                  )),
                  tileColor: isDarkMode ? backgroundDark.withOpacity(0.3) : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromCamera();
                  },
                ),
              ],
              
              // Opción de galería (solo mostrar si no es web)
              if (!kIsWeb) ...[
                ListTile(
                  leading: Icon(Icons.photo_library, color: pinkPrimary),
                  title: Text('Elegir desde galería', style: TextStyle(
                    color: isDarkMode ? textDarkMode : Colors.black87,
                  )),
                  tileColor: isDarkMode ? backgroundDark.withOpacity(0.3) : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromGallery();
                  },
                ),
              ],
              
              // Opción para web (si no hay soporte de cámara/galería)
              if (kIsWeb) ...[
                ListTile(
                  leading: Icon(Icons.photo_library, color: pinkPrimary),
                  title: Text('Subir imagen', style: TextStyle(
                    color: isDarkMode ? textDarkMode : Colors.black87,
                  )),
                  tileColor: isDarkMode ? backgroundDark.withOpacity(0.3) : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageForWeb();
                  },
                ),
              ],
              
              ListTile(
                leading: Icon(Icons.image_search, color: pinkPrimary),
                title: Text('Imágenes predeterminadas', style: TextStyle(
                  color: isDarkMode ? textDarkMode : Colors.black87,
                )),
                tileColor: isDarkMode ? backgroundDark.withOpacity(0.3) : null,
                onTap: () {
                  Navigator.pop(context);
                  _selectAsset();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromCamera() async {
    setState(() => _isLoadingImage = true);
    try {
      final path = await _pickerService.pickImageFromCamera();
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        setState(() {
          _selectedAsset = path;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingImage = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    setState(() => _isLoadingImage = true);
    try {
      final path = await _pickerService.pickImageFromGallery();
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        setState(() {
          _selectedAsset = path;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingImage = false);
    }
  }

  Future<void> _pickImageForWeb() async {
    setState(() => _isLoadingImage = true);
    try {
      final bytes = await _pickerService.pickImageBytesForWeb();
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _selectedAsset = 'data:image/jpeg;base64,${base64.encode(bytes)}';
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingImage = false);
    }
  }

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
                          _selectedImageBytes = null; // Es un asset, no bytes
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedAsset == asset ? pinkPrimary : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(isDarkMode ? 0.1 : 0.3),
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
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: isDarkMode ? cardLight : pinkLighter,
                              child: Icon(Icons.error, color: pinkDark),
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

  Widget _showSelectedImage() {
    if (_isLoadingImage) {
      return const Center(
        child: CircularProgressIndicator(color: pinkPrimary),
      );
    }

    if (_selectedAsset == null || _selectedAsset!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, color: pinkPrimary, size: 40),
            const SizedBox(height: 5),
            Text('Seleccionar imagen', style: TextStyle(color: pinkPrimary)),
          ],
        ),
      );
    }

    if (_selectedAsset!.startsWith('assets/')) {
      return Image.asset(
        _selectedAsset!, 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: pinkLighter,
          child: Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        ),
      );
    }
    
    // Para Web (data URL)
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
          child: Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        );
      }
    }
    
    // Para imágenes locales (path de archivo)
    if (_selectedAsset!.startsWith('/') || _selectedAsset!.contains('file:')) {
      return Image.file(
        File(_selectedAsset!), 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: pinkLighter,
          child: Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        ),
      );
    }
    
    // Para URLs web
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
          child: Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        ),
      );
    }
    
    // Por defecto
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: pinkPrimary, size: 40),
          const SizedBox(height: 5),
          Text('Imagen no compatible', style: TextStyle(color: pinkPrimary)),
        ],
      ),
    );
  }

  Future<void> _saveMemory() async {
    if (_isSaving) return;
    
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final date = _dateController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa un título'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona una fecha'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Crear memoria básica
      final memory = Memory(
        id: widget.existingMemory?.id ?? '',
        title: title,
        description: description,
        date: date,
        location: {
          'latitude': widget.location.latitude,
          'longitude': widget.location.longitude,
        },
        imageAsset: null, // Se asignará después de subir
      );

      // Si hay imagen seleccionada y es local (no asset), subirla
      if (_selectedImageBytes != null && 
          _selectedImageBytes!.isNotEmpty &&
          !(_selectedAsset?.startsWith('assets/') ?? true)) {
        
        print('📤 Subiendo imagen a Supabase...');
        
        // Usar saveMemoryWithImage que sube la imagen primero
        await _memoryService.saveMemoryWithImage(
          memory: memory,
          imageBytes: _selectedImageBytes!,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recuerdo guardado con imagen'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Si es un asset predeterminado o no hay imagen
        final memoryWithAsset = Memory(
          id: memory.id,
          title: memory.title,
          description: memory.description,
          date: memory.date,
          location: memory.location,
          imageAsset: _selectedAsset, // Puede ser asset o null
        );
        
        await _memoryService.saveMemory(memoryWithAsset);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recuerdo guardado'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Notificar al padre que se guardó
      widget.onSave(memory);
      
    } catch (e) {
      print('❌ Error guardando recuerdo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
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
                      ? 'Crear Nuevo Recuerdo' 
                      : 'Editar Recuerdo',
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
                      borderSide: const BorderSide(color: pinkPrimary, width: 2),
                    ),
                    prefixIcon: Icon(Icons.title, color: pinkPrimary),
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
                      borderSide: const BorderSide(color: pinkPrimary, width: 2),
                    ),
                    prefixIcon: Icon(Icons.description, color: pinkPrimary),
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
                          borderSide: const BorderSide(color: pinkPrimary, width: 2),
                        ),
                        prefixIcon: Icon(Icons.calendar_today, color: pinkPrimary),
                        fillColor: isDarkMode ? cardDark : Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Selector de imagen
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
                              ? cardDark.withOpacity(0.5) 
                              : pinkLighter.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pinkPrimary,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(isDarkMode ? 0.1 : 0.2),
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
                
                // Coordenadas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? cardDark : pinkLighter.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey[700]! : pinkLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: pinkPrimary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ubicación: ${widget.location.latitude.toStringAsFixed(6)}, ${widget.location.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                
                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : widget.onCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
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
                          backgroundColor: _isSaving ? Colors.grey : pinkPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          shadowColor: pinkPrimary.withOpacity(0.4),
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
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}