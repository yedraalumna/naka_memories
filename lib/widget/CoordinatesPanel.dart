import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/Memory.dart';

import '../constants/colors.dart';

class CoordinatesPanel extends StatefulWidget {
  final LatLng currentPosition;
  final Set<Marker> markers;
  final Function() onGoToCoordinates;
  final Function() onAddMarker;
  final Function(MarkerId) onRemoveMarker;

  final TextEditingController latController;
  final TextEditingController lngController;
  final List<Memory> memories;

  const CoordinatesPanel({
    super.key,
    required this.currentPosition,
    required this.markers,
    required this.onGoToCoordinates,
    required this.onAddMarker,
    required this.onRemoveMarker,
    required this.latController,
    required this.lngController,
    required this.memories,
  });

  @override
  State<CoordinatesPanel> createState() => _CoordinatesPanelState();
}

class _CoordinatesPanelState extends State<CoordinatesPanel> {

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(CoordinatesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Actualiza campos cuando cambia la posición de la cámara
    if (widget.currentPosition != oldWidget.currentPosition) {
      _updateControllers();
    }
  }

  // Sincroniza los controladores de texto con la posición actual
  void _updateControllers() {
    widget.latController.text = widget.currentPosition.latitude.toStringAsFixed(6);
    widget.lngController.text = widget.currentPosition.longitude.toStringAsFixed(6);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coordenadas de la cámara',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: pinkDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.latController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Latitud',
                    labelStyle: const TextStyle(color: pinkPrimary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: pinkPrimary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.lngController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Longitud',
                    labelStyle: const TextStyle(color: pinkPrimary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: pinkPrimary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onGoToCoordinates,
                  icon: const Icon(Icons.search, size: 20, color: Colors.white),
                  label: const Text('Ir a', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onAddMarker,
                  label: const Text('Marcar', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Lista de marcadores
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: widget.markers.map((marker) {
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pinkLighter,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pinkPrimary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: pinkPrimary),
                      const SizedBox(width: 6),
                      Text(
                        '${marker.position.latitude.toStringAsFixed(4)}, '
                            '${marker.position.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(color: pinkDark, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => widget.onRemoveMarker(marker.markerId),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: pinkPrimary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}