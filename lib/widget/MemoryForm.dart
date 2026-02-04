import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';
import 'dart:io'; 
import '../services/ImagePickerService.dart'; 
import 'package:flutter/foundation.dart';


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

  String? _selectedAsset;
  bool _isLoadingImage = false;

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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
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
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Seleccionar origen de imagen',
                style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: pinkDark
                ),
              ),
              const SizedBox(height: 20),
              
              // Opción de cámara (solo mostrar si no es web)
              if (!kIsWeb) ...[
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: pinkPrimary),
                  title: const Text('Sacar una foto'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromCamera();
                  },
                ),
              ],
              
              // Opción de galería (solo mostrar si no es web)
              if (!kIsWeb) ...[
                ListTile(
                  leading: const Icon(Icons.photo_library, color: pinkPrimary),
                  title: const Text('Elegir desde galería'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromGallery();
                  },
                ),
              ],
              
              // Opción para web (si no hay soporte de cámara/galería)
              if (kIsWeb) ...[
                ListTile(
                  leading: const Icon(Icons.photo_library, color: pinkPrimary),
                  title: const Text('Subir imagen'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageForWeb();
                  },
                ),
              ],
              
              ListTile(
                leading: const Icon(Icons.image_search, color: pinkPrimary),
                title: const Text('Imágenes predeterminadas'),
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
        setState(() => _selectedAsset = path);
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
        setState(() => _selectedAsset = path);
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
      final path = await _pickerService.pickImageForWeb();
      if (path != null) {
        setState(() => _selectedAsset = path);
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
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Seleccionar imagen',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: pinkDark
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
                              color: Colors.grey.withOpacity(0.3),
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
                              color: pinkLighter,
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

  Widget _showSelectedImage() {
    if (_isLoadingImage) {
      return const Center(
        child: CircularProgressIndicator(color: pinkPrimary),
      );
    }

    if (_selectedAsset == null || _selectedAsset!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, color: pinkPrimary, size: 40),
            SizedBox(height: 5),
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
          child: const Center(
            child: Icon(Icons.error, color: pinkDark, size: 40),
          ),
        ),
      );
    }
    
    // Para Web
    if (kIsWeb) {
      // Si es un path que comienza con 'blob:' o 'http'
      if (_selectedAsset!.startsWith('blob:') || 
          _selectedAsset!.startsWith('http://') || 
          _selectedAsset!.startsWith('https://')) {
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
      // Si es un string base64 (para web)
      if (_selectedAsset!.startsWith('data:image')) {
        return Image.memory(
          Uri.parse(_selectedAsset!).data!.contentAsBytes(),
          fit: BoxFit.cover,
        );
      }
      // Para otros casos en web
      return Image.network(_selectedAsset!, fit: BoxFit.cover);
    } else {
      // Para móvil
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
  }

  void _saveMemory() {
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

    final memory = Memory(
      id: widget.existingMemory?.id ?? 
          '${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      date: date,
      location: {
        'latitude': widget.location.latitude,
        'longitude': widget.location.longitude,
      },
      imageAsset: _selectedAsset ?? _availableAssets[0],
    );

    widget.onSave(memory);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: pinkDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Campo de título
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    prefixIcon: Icon(Icons.title, color: pinkPrimary),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: pinkPrimary, width: 2),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Campo de descripción
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    prefixIcon: Icon(Icons.description, color: pinkPrimary),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: pinkPrimary, width: 2),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
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
                      decoration: const InputDecoration(
                        labelText: 'Fecha *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        prefixIcon: Icon(Icons.calendar_today, color: pinkPrimary),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: pinkPrimary, width: 2),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Selector de imagen
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Imagen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: pinkDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImageOptions,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: pinkLighter.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pinkPrimary,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
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
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                
                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveMemory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          shadowColor: pinkPrimary.withOpacity(0.4),
                        ),
                        child: const Text(
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