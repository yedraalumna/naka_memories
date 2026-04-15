import 'package:flutter/material.dart';

/// Clase para obtener el ícono correspondiente a cada categoría
class CategoryIcons {
  // Método estatico que devuelve el ícono según la categoría
  static IconData getIcon(String category) {
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
}
