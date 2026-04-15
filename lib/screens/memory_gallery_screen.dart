import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../services/MemoryService.dart';
import '../models/Memory.dart';
import '../widget/memory_detail_screen.dart';
import 'coordinate_input_screen.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import '../providers/favorite_provider.dart';
import 'favorite_screen.dart';
import '../widget/MemoryThumbnail.dart';
import '../providers/category_provider.dart';
import '../widget/pin_dialog.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widget/memory_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pantalla principal de la galería, muestra las carpetas (categorías)
/// y los recuerdos que hay dentro de cada una, manejando los permisos y las carpetas protegidas por un PIN
class MemoryGalleryScreen extends StatefulWidget {
  const MemoryGalleryScreen({super.key});

  @override
  State<MemoryGalleryScreen> createState() => _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  final MemoryService _memoryService = MemoryService();
  List<Memory> _memories = [];
  bool _isLoading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  /// Verfica que el usuario actual es el creador original de la categoría
  bool _isOwner(String category) {
    final categoryMemories =
        _memories.where((m) => m.category == category).toList();
    if (categoryMemories.isEmpty) {
      return true; // Si está vacía la crea el propio usuario
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    // Si no hay creatorId antiguo, es del usuario actual
    final ownerId = categoryMemories.first.creatorId ?? currentUser?.id;
    return currentUser?.id == ownerId;
  }

  /// Verifica si el usuario actual tiene permisos de 'editor' o 'admin'
  /// para poder añadir o editar recuerdos en la categoría/carpeta
  bool _canAddOrEdit(String category) {
    if (_isOwner(category)) return true; // El dueño siempre puede

    final categoryMemories =
        _memories.where((m) => m.category == category).toList();
    if (categoryMemories.isEmpty) return false;

    final currentUser = Supabase.instance.client.auth.currentUser;
    final role = categoryMemories.first.sharedRoles?[currentUser?.email];

    return role == 'editor' || role == 'admin';
  }

  /// Verifica si el usuario tiene permisos de 'admin' (o es el creador) para poder eliminar un recuerdo
  bool _canDelete(Memory memory) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (memory.creatorId == currentUser?.id) {
      return true; // El dueño siempre puede
    }

    final role = memory.sharedRoles?[currentUser?.email];
    return role == 'admin';
  }

  /// Método que hace que se carguen todos los recuerdos del usuario desde la base de datos
  /// y los almacena en la lista de favoritos para que se puedan ver en toda la app
  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    try {
      final memories = await _memoryService.getMemories();
      if (mounted) {
        Provider.of<FavoriteProvider>(context, listen: false)
            .loadFavorites(memories);
        setState(() {
          _memories = memories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando recuerdos: $e');
      if (mounted) {
        setState(() {
          _memories = [];
          _isLoading = false;
        });
      }
    }
  }

  /// Agrupa la lista de recuerdos en un mapa por categorías
  Map<String, List<Memory>> _groupMemoriesByCategory() {
    Map<String, List<Memory>> grouped = {};
    for (var memory in _memories) {
      grouped.putIfAbsent(memory.category, () => []).add(
          memory); // Agrega la memoria a la categoría (PutIfAbsent es un if/else compacto)
    }
    return grouped;
  }

  /// Coge el último recuerdo añadido a la categoría para usarlo como miniatura de la carpeta
  /// Si no hay recuerdos, devuelve null para mostrar el icono de carpeta vacía
  Memory? _getLastMemoryForCategory(
      String category, Map<String, List<Memory>> grouped) {
    final memories = grouped[category];
    if (memories == null || memories.isEmpty) return null;
    return memories.last;
  }

  /// Maneja el evento de tocar una carpeta. Si tiene PIN, se abre el diálogo del PIN antes de abrirla
  Future<void> _onFolderTap(
      String category, Map<String, List<Memory>> grouped) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final folderHasPassword = categoryProvider.isCategoryProtected(category);
    final passwordHash = categoryProvider.getPasswordHash(category);

    if (folderHasPassword && passwordHash != null && passwordHash.isNotEmpty) {
      final bool? correcto = await showDialog<bool>(
        context: context,
        builder: (ctx) => PinDialog(
          correctHash: passwordHash,
          titulo: 'PIN de: $category',
        ),
      );

      if (correcto == true && mounted) {
        setState(() => _selectedCategory = category);
      }
    } else {
      setState(() => _selectedCategory = category);
    }
  }

  /// Muestra el modal para ponerle PIN a una carpeta
  void _showProtectFolderDialog(String category) {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proteger Carpeta'),
        content: SingleChildScrollView(
          // hace que el teclado no tape el contenido
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Ingresa un PIN de 6 dígitos para proteger esta carpeta:'),
              const SizedBox(height: 20),
              PinCodeTextField(
                appContext: context,
                controller: pinController,
                length: 6,
                obscureText: true,
                animationType: AnimationType.fade,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(8),
                  fieldHeight: 45,
                  fieldWidth: 35,
                  activeFillColor: pinkLighter,
                  activeColor: pinkPrimary,
                ),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
            onPressed: () async {
              final pin = pinController.text;
              if (pin.length == 6) {
                final hash = sha256.convert(utf8.encode(pin)).toString();
                final categoryProvider =
                    Provider.of<CategoryProvider>(context, listen: false);

                await categoryProvider.setCategoryPassword(category, hash);

                for (var memory
                    in _memories.where((m) => m.category == category)) {
                  final updatedMemory = memory.copyWith(
                    hasPassword: true,
                    passwordHash: hash,
                  );
                  await _memoryService.saveMemory(updatedMemory);
                }

                _loadMemories();
                if (!context.mounted) {
                  return;
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Carpeta protegida con éxito')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El PIN debe tener 6 dígitos')),
                );
              }
            },
            child: const Text('Proteger'),
          ),
        ],
      ),
    );
  }

  /// Navega al formulario para crear un recuerdo y si hay una categoría seleccionada, se la asigna
  void _navigateToCreateMemory() {
    const ubicacionPorDefecto = LatLng(0.0, 0.0);

    showDialog(
      context: context,
      builder: (context) => MemoryForm(
        location: ubicacionPorDefecto,
        existingMemory: _selectedCategory != null
            ? Memory(
                id: '',
                title: '',
                description: '',
                date: DateTime.now().toString().split(' ')[0],
                location: {'latitude': 0.0, 'longitude': 0.0},
                category: _selectedCategory!,
              )
            : null,
        onSave: (newMemory) async {
          await _memoryService.saveMemory(newMemory);
          if (!context.mounted) {
            return;
          }

          Navigator.pop(context);
          _loadMemories();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  /// Muestra el modal para escribir el nombre y crear una nueva carpeta vacía
  void _showNewCategoryDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: const Text('Nueva Carpeta',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el nombre de la nueva carpeta:',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Ej: Vacaciones 2024',
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.folder, size: 32),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final newCategory = controller.text.trim();
                          if (newCategory.isNotEmpty) {
                            Provider.of<CategoryProvider>(context,
                                    listen: false)
                                .addCategoryLocally(newCategory);
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Carpeta "$newCategory" creada'),
                                backgroundColor: pinkPrimary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child:
                            const Text('Crear', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Muestra el modal para dar o eliminar permisos (roles) a otros usuarios por correo sobre toda la categoría/carpeta
  void _showShareCategoryDialog(String categoryToShare) {
    final categoryMemories =
        _memories.where((m) => m.category == categoryToShare).toList();
    if (categoryMemories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Añade un recuerdo primero para compartir.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    final String ownerId =
        categoryMemories.first.creatorId ?? currentUser?.id ?? '';
    final bool isOwner = currentUser?.id == ownerId;

    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Solo el dueño original puede administrar los permisos de esta carpeta.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final TextEditingController emailController = TextEditingController();
    String selectedRole = 'lector';
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDarkMode ? cardDark : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compartir "$categoryToShare"',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? textLight : Colors.black87)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade900
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.shield, color: pinkPrimary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Propietario:\n${currentUser?.email}',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.black87)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  Text(
                    'Escribe un correo electrónico:',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? textLight : Colors.black87),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? textLight : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'amigo@correo.com',
                      hintStyle: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[500] : Colors.grey[600]),
                      fillColor: isDarkMode ? cardDark : Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: pinkPrimary, width: 2)),
                      prefixIcon: const Icon(Icons.email, color: pinkPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    isDense: false,
                    dropdownColor: isDarkMode ? cardDark : Colors.white,
                    style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? textLight : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Permiso otorgado',
                      labelStyle: TextStyle(
                          fontSize: 14,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey)),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'lector',
                          child: Text('Lector (Solo ver)',
                              style: TextStyle(
                                  color: isDarkMode
                                      ? textLight
                                      : Colors.black87))),
                      DropdownMenuItem(
                          value: 'editor',
                          child: Text('Editor (Ver y editar)',
                              style: TextStyle(
                                  color: isDarkMode
                                      ? textLight
                                      : Colors.black87))),
                      DropdownMenuItem(
                          value: 'admin',
                          child: Text('Todo (Admin)',
                              style: TextStyle(
                                  color: isDarkMode
                                      ? textLight
                                      : Colors.black87))),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() => selectedRole = newValue);
                      }
                    },
                  ),

                  // Lista de usuarios con acceso y sus roles
                  if (categoryMemories.first.sharedRoles != null &&
                      categoryMemories.first.sharedRoles!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Usuarios con acceso:',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? textLight : Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? Colors.grey[900] : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDarkMode
                                ? Colors.grey[800]!
                                : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: categoryMemories.first.sharedRoles!.entries
                            .map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.person,
                                    color: pinkPrimary, size: 20),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(entry.key,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: isDarkMode
                                                ? Colors.grey[300]
                                                : Colors.black87))),
                                const SizedBox(width: 8),

                                // Menú de permisos por usuario con la opción de cambiar rol o quitar (eliminarlo)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: entry.value == 'quitar'
                                          ? (isDarkMode
                                              ? Colors.red
                                                  .withValues(alpha: 0.2)
                                              : Colors.red.shade50)
                                          : (isDarkMode
                                              ? pinkLighter.withValues(
                                                  alpha: 0.2)
                                              : pinkLighter),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: entry.value,
                                      icon: const Icon(Icons.arrow_drop_down,
                                          size: 20, color: pinkDark),
                                      isDense: false,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? pinkLight
                                              : pinkDark),
                                      dropdownColor: isDarkMode
                                          ? Colors.grey[800]
                                          : Colors.white,
                                      items: [
                                        DropdownMenuItem(
                                            value: 'lector',
                                            child: Text('Lector',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? textLight
                                                        : Colors.black87))),
                                        DropdownMenuItem(
                                            value: 'editor',
                                            child: Text('Editor',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? textLight
                                                        : Colors.black87))),
                                        DropdownMenuItem(
                                            value: 'admin',
                                            child: Text('Admin',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? textLight
                                                        : Colors.black87))),
                                        const DropdownMenuItem(
                                            value: 'quitar',
                                            child: Text('QUITAR',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                      ],
                                      onChanged: (String? newRole) async {
                                        if (newRole != null &&
                                            newRole != entry.value) {
                                          final scaffoldMessenger =
                                              ScaffoldMessenger.of(context);

                                          setDialogState(() {
                                            if (newRole == 'quitar') {
                                              categoryMemories
                                                  .first.sharedRoles!
                                                  .remove(entry.key);
                                            } else {
                                              categoryMemories.first
                                                      .sharedRoles![entry.key] =
                                                  newRole;
                                            }
                                          });

                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Actualizando accesos...'),
                                                backgroundColor:
                                                    Colors.blueGrey,
                                                duration: Duration(seconds: 1)),
                                          );

                                          try {
                                            await _memoryService
                                                .shareCategoryWithRole(
                                                    categoryToShare,
                                                    entry.key,
                                                    newRole);
                                            _loadMemories();
                                          } catch (e) {
                                            scaffoldMessenger.showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Error al actualizar: $e'),
                                                  backgroundColor: Colors.red),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Cancelar',
                          style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.grey[300] : null)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pinkPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final email = emailController.text.trim();
                        if (email.isNotEmpty) {
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          Navigator.pop(dialogContext);

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                                content: Text('Otorgando permisos a $email...'),
                                backgroundColor: Colors.blueGrey),
                          );
                          try {
                            await _memoryService.shareCategoryWithRole(
                                categoryToShare, email, selectedRole);
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Permisos asignados con éxito'),
                                    backgroundColor: Colors.green),
                              );
                              _loadMemories();
                            }
                          } catch (e) {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Compartir',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
  }

  /// Muestra el modal de detalles del recuerdo, con todas, alguna o ninguna opción depende del rol del usuario
  void _showMemoryDetails(BuildContext context, Memory memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemoryDetailScreen(
        memory: memory,
        onEdit: () async {
          // Solo puede editar si tiene permiso
          if (!_canAddOrEdit(memory.category)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'No tienes permiso para editar. Eres Lector de esta carpeta.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ));
            return;
          }
          Navigator.pop(context);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => CoordinateInputScreen(existingMemory: memory),
            ),
          );
          if (result != null && result is Memory) {
            await _memoryService.saveMemory(result);
            _loadMemories();
          }
        },
        onDelete: () async {
          // Solo puede borrar si tiene permiso
          if (!_canDelete(memory)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'No tienes permisos de Administrador para eliminar este recuerdo.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ));
            return;
          }
          try {
            await _memoryService.deleteMemory(memory.id);

            if (!context.mounted) {
              return;
            }

            Navigator.pop(context);
            _loadMemories();
          } catch (e) {
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        },
        onUpdate: (updatedMemory) async {
          await _memoryService.saveMemory(updatedMemory);
          _loadMemories();
        },
      ),
    );
  }

  /// Construye el grid principal que muestra todas las carpetas/categorías
  Widget _buildFolderGrid(
    BuildContext context,
    List<String> categories,
    Map<String, List<Memory>> grouped,
    ThemeProvider themeProvider,
    CategoryProvider categoryProvider,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No hay carpetas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final lastMemory = _getLastMemoryForCategory(cat, grouped);
        final isProtected = categoryProvider.isCategoryProtected(cat);

        final bool isMine = _isOwner(cat);
        final bool isSharedByMe =
            isMine && (lastMemory?.sharedWith.isNotEmpty ?? false);

        final Color folderColor = isMine
            ? pinkPrimary.withValues(alpha: 0.8)
            : lilaFuerte.withValues(alpha: 0.8);
        final Color bgColor = themeProvider.isDarkMode
            ? cardDark
            : (isMine ? pinkLighter : lilaClarito);
        final IconData folderIcon = isMine
            ? (isSharedByMe ? Icons.folder_shared : Icons.folder)
            : Icons.folder_special;

        return GestureDetector(
          onTap: () => _onFolderTap(cat, grouped),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      folderIcon,
                      size: 90,
                      color: folderColor,
                    ),
                    if (lastMemory != null && lastMemory.imageAsset != null)
                      Positioned(
                        top: 30,
                        child: Container(
                          width: 45,
                          height: 35,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2)
                            ],
                          ),
                          child: MemoryThumbnail(
                            imagePath: lastMemory.imageAsset,
                            width: 45,
                            height: 35,
                            borderRadius: 4,
                          ),
                        ),
                      ),
                    if (isProtected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: pinkPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cat,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: themeProvider.isDarkMode
                        ? textDarkMode
                        : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Etiqueta del propietario o número de recuerdos que hay dentro depende de si el usuario es el dueño o no de la carpeta
                if (!isMine && lastMemory?.creatorEmail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'De: ${lastMemory!.creatorEmail}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: lilaFuerte,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Text(
                    '${grouped[cat]?.length ?? 0} recuerdos',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construye el grid secundario que muestra los recuerdos una vez dentro de una carpeta
  Widget _buildMemoryList(
    BuildContext context,
    List<Memory> memories,
    ThemeProvider themeProvider,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final memory = memories[index];
        return GestureDetector(
          onTap: () => _showMemoryDetails(context, memory),
          child: Card(
            elevation: 3,
            color: themeProvider.isDarkMode ? cardDark : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: MemoryThumbnail(
                      imagePath: memory.imageAsset,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              memory.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: themeProvider.isDarkMode
                                    ? textDarkMode
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              memory.date.split('T')[0],
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Consumer<FavoriteProvider>(
                        builder: (context, fav, _) {
                          final isFav = fav.isFavorite(memory.id);
                          return IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? pinkPrimary : Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => fav.toggleFavorite(memory.id),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final groupedMemories = _groupMemoriesByCategory();
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final categories = categoryProvider.categories;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? backgroundDark : Colors.white,
      appBar: AppBar(
        // Título y Subtítulo del AppBar
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedCategory ?? 'Mis Carpetas',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            // Si la carpeta no es del usuario, se muestra el dueño
            if (_selectedCategory != null && !_isOwner(_selectedCategory!))
              Builder(
                builder: (context) {
                  // Si no hay creatorId antiguo, es del usuario actual
                  final memoryWithOwner = _memories.firstWhere(
                    (m) =>
                        m.category == _selectedCategory &&
                        m.creatorEmail != null &&
                        m.creatorEmail!.isNotEmpty,
                    orElse: () => _memories
                        .firstWhere((m) => m.category == _selectedCategory),
                  );

                  if (memoryWithOwner.creatorEmail != null) {
                    return Text(
                      'Propietario: ${memoryWithOwner.creatorEmail}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.normal),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
        backgroundColor: pinkPrimary,
        leading: _selectedCategory != null
            ? IconButton(
                iconSize: 32,
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : null,
        actions: [
          // Solo el propietario ve el botón de proteger carpeta con PIN
          if (_selectedCategory != null && _isOwner(_selectedCategory!))
            IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.lock_outline, color: Colors.white),
              tooltip: 'Proteger esta carpeta con PIN',
              onPressed: () => _showProtectFolderDialog(_selectedCategory!),
            ),

          // Solo el propietario ve el botón de compartir carpeta con otros usuarios
          if (_selectedCategory != null && _isOwner(_selectedCategory!))
            IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.folder_shared, color: Colors.white),
              tooltip: 'Compartir esta carpeta con un usuario',
              onPressed: () => _showShareCategoryDialog(_selectedCategory!),
            ),

          // Los lectores no ven el boton de agregar recuerdo en la carpeta, los editores y administradores si
          if (_selectedCategory != null && _canAddOrEdit(_selectedCategory!))
            IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Agregar recuerdo a esta carpeta',
              onPressed: _navigateToCreateMemory,
            ),

          // Solo se muestra el botón de crear nueva carpeta si el usuario no está dentro de una (en la vista principal)
          if (_selectedCategory == null)
            IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.create_new_folder, color: Colors.white),
              tooltip: 'Crear nueva carpeta',
              onPressed: _showNewCategoryDialog,
            ),
          IconButton(
            iconSize: 32,
            padding: const EdgeInsets.all(12),
            icon: const Icon(Icons.favorite, color: Colors.white),
            tooltip: 'Ver favoritos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoriteScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: pinkPrimary))
          : _memories.isEmpty
              ? _buildEmptyState(themeProvider)
              : _selectedCategory == null
                  ? _buildFolderGrid(
                      context,
                      categories,
                      groupedMemories,
                      themeProvider,
                      categoryProvider,
                    )
                  : _buildMemoryList(context,
                      groupedMemories[_selectedCategory] ?? [], themeProvider),
    );
  }

  /// Muestra el inicio vacío cuando la cuenta aún no tiene ningún recuerdo guardado
  Widget _buildEmptyState(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No hay recuerdos aún',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _navigateToCreateMemory,
            style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
            child: const Text('Crear mi primer recuerdo',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
