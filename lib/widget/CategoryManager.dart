import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/Memory.dart';
import '../services/MemoryService.dart';
import '../providers/theme_provider.dart';

class CategoryManager extends StatefulWidget {
  const CategoryManager({Key? key}) : super(key: key);

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager> {
  final MemoryService _memoryService = MemoryService();
  List<String> _categories = [];
  bool _isLoading = true;
  bool _showDefaultHint = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _memoryService.getAllCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar carpetas: $e');
    }
  }

  Future<void> _createCategory() async {
    final TextEditingController controller = TextEditingController();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? cardDark : Colors.white,
        title: const Text('Nueva Carpeta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: isDarkMode ? textDarkMode : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Nombre de la carpeta',
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
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: pinkPrimary,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _memoryService.createCategory(result);
        await _loadCategories();
        _showSuccess('Carpeta "$result" creada');
      } catch (e) {
        _showError('Error al crear carpeta: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _renameCategory(String oldName) async {
    final TextEditingController controller = TextEditingController(text: oldName);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
        await _memoryService.renameCategory(oldName, result);
        await _loadCategories();
        _showSuccess('Carpeta renombrada: $oldName → $result');
      } catch (e) {
        _showError('Error al renombrar: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCategory(String categoryName) async {
    if (categoryName == 'General') {
      _showError('No se puede eliminar la carpeta "General"');
      return;
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    // Verificar si es una categoría predeterminada
    final isDefault = false;
    final warningMessage = isDefault
        ? '⚠️ Esta es una carpeta predeterminada.\n\n'
        : '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? cardDark : Colors.white,
        title: const Text('Eliminar Carpeta'),
        content: Text(
          '${warningMessage}¿Estás seguro de eliminar la carpeta "$categoryName"?\n\n'
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
        await _loadCategories();
        _showSuccess('Carpeta "$categoryName" eliminada');
      } catch (e) {
        _showError('Error al eliminar: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Carpetas'),
        backgroundColor: isDarkMode ? backgroundDark : backgroundLight,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: pinkPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Botón opcional para restaurar categorías predeterminadas
          IconButton(
            icon: Icon(Icons.restore, color: pinkPrimary),
            onPressed: () => _showRestoreDialog(),
            tooltip: 'Restaurar carpetas predeterminadas',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: pinkPrimary),
            )
          : Column(
              children: [
                if (_showDefaultHint)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pinkPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pinkPrimary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: pinkPrimary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Las carpetas predeterminadas también se pueden editar o eliminar. '
                            'Puedes restaurarlas desde el menú superior.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? textDarkMode : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: pinkPrimary),
                          onPressed: () => setState(() => _showDefaultHint = false),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 80,
                                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay carpetas',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Toca el botón + para crear una',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isGeneral = category == 'General';
                            final isDefault = false;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              color: isDarkMode ? cardDark : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: pinkPrimary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(category),
                                    color: pinkPrimary,
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode ? textDarkMode : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.orange.withOpacity(0.5),
                                          ),
                                        ),
                                        child: Text(
                                          'Predeterminada',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botón Renombrar (excepto para General)
                                    if (!isGeneral)
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _renameCategory(category),
                                        tooltip: 'Renombrar',
                                      ),
                                    // Botón Eliminar (excepto para General)
                                    if (!isGeneral)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteCategory(category),
                                        tooltip: 'Eliminar',
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCategory,
        backgroundColor: pinkPrimary,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Nueva carpeta',
      ),
    );
  }

  Future<void> _showRestoreDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? cardDark : Colors.white,
        title: const Text('Restaurar Carpetas Predeterminadas'),
        content: Text(
          '¿Quieres restaurar las carpetas predeterminadas?\n\n'
          'Carpetas a restaurar:\nGeneral\nViajes\nAmigos\nFamilia\nComida\nEstudio\n\n'
          'Nota: Esto NO eliminará tus carpetas personalizadas, '
          'solo añadirá las que falten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: pinkPrimary,
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _memoryService.restoreDefaultCategories();
        await _loadCategories();
        _showSuccess('Carpetas predeterminadas restauradas');
      } catch (e) {
        _showError('Error al restaurar: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'viajes':
        return Icons.flight;
      case 'amigos':
        return Icons.people;
      case 'familia':
        return Icons.home;
      case 'comida':
        return Icons.restaurant;
      case 'estudio':
        return Icons.school;
      case 'trabajo':
        return Icons.work;
      case 'deportes':
        return Icons.sports;
      default:
        return Icons.folder;
    }
  }
}