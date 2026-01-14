import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/Memory.dart';
import '../constants/colors.dart';

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

  String? _selectedAsset;

  // Lista de assets disponibles
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

  //seleccionamos la fecha
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

  // metodo para seleccionar las imagenes
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
                  color: pinkDark,
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
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            asset,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: pinkLighter,
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  //guardamos el recuerdo
  void _saveMemory() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa un título'),
          backgroundColor: pinkPrimary,
        ),
      );
      return;
    }

    final memory = Memory(
      id: widget.existingMemory?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      description: _descriptionController.text,
      date: _dateController.text,
      location: {
        'latitude': widget.location.latitude,
        'longitude': widget.location.longitude,
      },
      imageAsset: _selectedAsset ?? _availableAssets[0],
    );

    // Solo pasamos memory
    widget.onSave(memory);
  }

  @override
  Widget build(BuildContext context) {
    // Determina el título basado en si existe una memoria
    String tituloDialogo;
    if (widget.existingMemory == null) {
      tituloDialogo = 'Crear Nuevo Recuerdo';
    } else {
      tituloDialogo = 'Editar Recuerdo';
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tituloDialogo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pinkDark,),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Campo de Título
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 15),

              // Campo de Descripción
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 15),

              // Campo de Fecha
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Selección de Asset
              GestureDetector(
                onTap: _selectAsset,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: pinkLighter,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pinkPrimary, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedAsset != null && _selectedAsset!.isNotEmpty
                        ? Image.asset(
                      _selectedAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.error, color: Colors.pinkAccent, size: 40),
                      ),
                    )
                        : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library, color: pinkPrimary, size: 40),
                          SizedBox(height: 5),
                          Text(
                            'Seleccionar imagen',
                            style: TextStyle(color: pinkPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Presiona para cambiar la imagen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),

              // Botones de accion
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveMemory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pinkPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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