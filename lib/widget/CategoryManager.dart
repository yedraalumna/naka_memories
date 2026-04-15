import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../providers/category_provider.dart';
import '../providers/theme_provider.dart';
import 'package:crypto/crypto.dart';
import 'pin_dialog.dart';
import '../constants/category_icons.dart';

class CategoryManager extends StatefulWidget {
  const CategoryManager({super.key});

  @override
  State<CategoryManager> createState() {
    return _CategoryManagerState();
  }
}

class _CategoryManagerState extends State<CategoryManager> {
  bool _isLoading = true;
  bool _showDefaultHint = true;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  //cargamos las categorias
  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.loadCategories();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error al cargar carpetas: $e');
    }
  }

  Future<void> _createCategory() async {
    // Controlador para el campo de texto
    final TextEditingController controller = TextEditingController();

    // Obtenemos el tema para saber si es modo oscuro
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Mostramos el diálogo para pedir el nombre de la nueva categoría
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        // Colores según el tema
        Color colorFondo;
        Color colorTexto;

        if (isDarkMode == true) {
          colorFondo = cardDark;
          colorTexto = textDarkMode;
        } else {
          colorFondo = Colors.white;
          colorTexto = Colors.black87;
        }

        return AlertDialog(
          backgroundColor: colorFondo,
          title: const Text('Nueva Carpeta'),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: colorTexto),
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
              onPressed: () {
                Navigator.pop(context);
              },
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
        );
      },
    );

    // Si el usuario escribió un nombre y pulsó Crear
    if (result != null) {
      // Mostramos el círculo de carga
      setState(() {
        _isLoading = true;
      });

      try {
        // Obtenemos el proveedor de categorías
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);

        // Creamos la nueva categoría
        await categoryProvider.createCategory(result);

        // Recargamos la lista de categorías
        await _loadCategories();

        // Mostramos mensaje de éxito
        _showSuccess('Carpeta "$result" creada');
      } catch (e) {
        // Si hay error, mostramos mensaje de error
        _showError('Error al crear carpeta: $e');

        // Ocultamos el círculo de carga
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _renameCategory(String oldName) async {
    // Controlador con el nombre actual
    final TextEditingController controller =
        TextEditingController(text: oldName);

    // Obtenemos el tema
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Mostramos el diálogo para pedir el nuevo nombre
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        // Colores según el tema
        Color colorFondo;
        Color colorTexto;

        if (isDarkMode == true) {
          colorFondo = cardDark;
          colorTexto = textDarkMode;
        } else {
          colorFondo = Colors.white;
          colorTexto = Colors.black87;
        }

        return AlertDialog(
          backgroundColor: colorFondo,
          title: const Text('Renombrar Carpeta'),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: colorTexto),
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
              onPressed: () {
                Navigator.pop(context);
              },
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
        );
      },
    );

    // Si el usuario escribió un nuevo nombre y pulsó Renombrar
    if (result != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);
        await categoryProvider.renameCategory(oldName, result);
        _showSuccess('Carpeta renombrada: $oldName → $result');
      } catch (e) {
        _showError('Error al renombrar: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCategory(String categoryName) async {
    // No se puede eliminar la carpeta General
    if (categoryName == 'General') {
      _showError('No se puede eliminar la carpeta "General"');
      return;
    }

    // Obtenemos el tema
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Preguntamos al usuario si está seguro
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        // Colores según el tema
        Color colorFondo;
        if (isDarkMode == true) {
          colorFondo = cardDark;
        } else {
          colorFondo = Colors.white;
        }

        return AlertDialog(
          backgroundColor: colorFondo,
          title: const Text('Eliminar Carpeta'),
          content: Text(
            '¿Estás seguro de eliminar la carpeta "$categoryName"?\n\n'
            'Todos los recuerdos de esta carpeta se moverán a "General"',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    // Si el usuario confirmó, eliminamos la carpeta
    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);
        await categoryProvider.deleteCategory(categoryName);
        await _loadCategories();
        _showSuccess('Carpeta "$categoryName" eliminada');
      } catch (e) {
        _showError('Error al eliminar: $e');
        setState(() {
          _isLoading = false;
        });
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
    final categoryProvider = Provider.of<CategoryProvider>(context);

    // Colores según el tema
    Color colorAppBar;
    Color colorTextoHint;
    Color colorCard;
    Color colorBordeCard;
    Color colorTextoTitulo;

    if (isDarkMode == true) {
      colorAppBar = backgroundDark;
      colorTextoHint = textDarkMode;
      colorCard = cardDark;
      colorBordeCard = Colors.grey[700]!;
      colorTextoTitulo = textDarkMode;
    } else {
      colorAppBar = backgroundLight;
      colorTextoHint = Colors.black87;
      colorCard = Colors.white;
      colorBordeCard = Colors.grey[200]!;
      colorTextoTitulo = Colors.black87;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Carpetas'),
        backgroundColor: colorAppBar,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: pinkPrimary),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore, color: pinkPrimary),
            onPressed: () {
              _showRestoreDialog();
            },
            tooltip: 'Restaurar carpetas predeterminadas',
          ),
        ],
      ),
      body: () {
        // Si está cargando, mostrar círculo de progreso
        if (categoryProvider.isLoading == true || _isLoading == true) {
          return const Center(
            child: CircularProgressIndicator(color: pinkPrimary),
          );
        }

        // Si no está cargando, mostrar el contenido
        return Column(
          children: [
            // Mensaje de ayuda para el usuario y es solo la primera vez
            if (_showDefaultHint == true)
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
                    const Icon(Icons.info_outline,
                        color: pinkPrimary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Puedes crear, editar o eliminar carpetas.\n'
                        'Las carpetas predeterminadas también se pueden eliminar',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorTextoHint,
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, size: 16, color: pinkPrimary),
                      onPressed: () {
                        setState(() {
                          _showDefaultHint = false;
                        });
                      },
                    ),
                  ],
                ),
              ),

            Expanded(
              child: () {
                // Si no hay categorías, mostramos un mensaje
                if (categoryProvider.categories.isEmpty == true) {
                  Color colorIcono;
                  Color colorTexto1;
                  Color colorTexto2;

                  if (isDarkMode == true) {
                    colorIcono = Colors.grey[600]!;
                    colorTexto1 = Colors.grey[400]!;
                    colorTexto2 = Colors.grey[500]!;
                  } else {
                    colorIcono = Colors.grey[400]!;
                    colorTexto1 = Colors.grey[600]!;
                    colorTexto2 = Colors.grey[500]!;
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 80,
                          color: colorIcono,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay carpetas',
                          style: TextStyle(
                            fontSize: 18,
                            color: colorTexto1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toca el botón + para crear una',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorTexto2,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Si hay categorías, mostrarlas en una lista
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categoryProvider.categories.length,
                  itemBuilder: (context, index) {
                    final category = categoryProvider.categories[index];
                    final isGeneral = (category == 'General');

                    // Color del candado
                    Color colorCandado;
                    if (categoryProvider.isCategoryProtected(category) ==
                        true) {
                      colorCandado = lilaMedio;
                    } else {
                      colorCandado = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      color: colorCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorBordeCard),
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
                            CategoryIcons.getIcon(category),
                            color: pinkPrimary,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorTextoTitulo,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón de candado para cuando la carpeta esta protegida con un PIN
                            IconButton(
                              icon: Icon(
                                () {
                                  if (categoryProvider
                                          .isCategoryProtected(category) ==
                                      true) {
                                    return Icons.lock;
                                  } else {
                                    return Icons.lock_open;
                                  }
                                }(),
                                color: colorCandado,
                              ),
                              onPressed: () {
                                _manageCategoryPin(category);
                              },
                              tooltip: 'Proteger con PIN',
                            ),
                            // Botón de editar, solo si no es General
                            if (isGeneral == false)
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: lilaClarito),
                                onPressed: () {
                                  _renameCategory(category);
                                },
                                tooltip: 'Renombrar',
                              ),
                            // Botón de eliminar, solo si no es General
                            if (isGeneral == false)
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: lilaFuerte),
                                onPressed: () {
                                  _deleteCategory(category);
                                },
                                tooltip: 'Eliminar',
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }(),
            ),
          ],
        );
      }(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCategory,
        backgroundColor: pinkPrimary,
        tooltip: 'Nueva carpeta',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _manageCategoryPin(String categoryName) async {
    // Obtenemos los proveedores
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final isProtected = categoryProvider.isCategoryProtected(categoryName);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // si la carpeta ya tiene PIN
    if (isProtected == true) {
      final currentHash = categoryProvider.getPasswordHash(categoryName);

      // Si no hay hash, mostramos error
      if (currentHash == null || currentHash.isEmpty) {
        _showError('No se encontró el PIN actual de esta carpeta');
        return;
      }

      // Pedimos el PIN actual para verificar
      final bool? authorized = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PinDialog(
            correctHash: currentHash,
            titulo: 'Verificar PIN para eliminar',
          );
        },
      );

      // Si el PIN es incorrecto
      if (authorized != true) {
        // Preguntamos si quiere recuperar el PIN
        final bool? forgotPin = await showDialog<bool>(
          context: context,
          builder: (context) {
            // Color de fondo según el tema
            Color colorFondo;
            if (isDarkMode == true) {
              colorFondo = cardDark;
            } else {
              colorFondo = Colors.white;
            }

            return AlertDialog(
              backgroundColor: colorFondo,
              title: const Text('PIN incorrecto'),
              content: const Text(
                'Si no recuerdas el PIN, puedes verificar tu contraseña de inicio de sesión para cambiarlo.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
                  child: const Text('Olvidé mi PIN'),
                ),
              ],
            );
          },
        );

        // Si quiere recuperar el PIN
        if (forgotPin == true) {
          await _recoverPinWithLoginPassword(
            categoryName: categoryName,
            categoryProvider: categoryProvider,
            isDarkMode: isDarkMode,
          );
        }
        return;
      }

      // PIN correcto, preguntamos si quiere eliminar el PIN
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          // Color de fondo según el tema
          Color colorFondo;
          if (isDarkMode == true) {
            colorFondo = cardDark;
          } else {
            colorFondo = Colors.white;
          }

          return AlertDialog(
            backgroundColor: colorFondo,
            title: const Text('Eliminar PIN'),
            content:
                Text('¿Quieres eliminar el PIN de la carpeta "$categoryName"?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          );
        },
      );

      // Si confirma, eliminamos el PIN
      if (confirm == true) {
        await categoryProvider.setCategoryPassword(categoryName, null);
        _showSuccess('PIN eliminado de "$categoryName"');
        setState(() {});
      }
    }
    // La carpeta no tiene pin, preguntamos si quiere ponerle uno
    else {
      final TextEditingController pinController = TextEditingController();
      final TextEditingController confirmController = TextEditingController();

      // Mostramos diálogo para pedir el nuevo PIN
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          // Color de fondo según el tema
          Color colorFondo;
          if (isDarkMode == true) {
            colorFondo = cardDark;
          } else {
            colorFondo = Colors.white;
          }

          return AlertDialog(
            backgroundColor: colorFondo,
            title: const Text('Proteger Carpeta con PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Establece un PIN de 6 dígitos para proteger esta carpeta'),
                const SizedBox(height: 20),
                // Campo para el PIN
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: 'PIN',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Campo para confirmar el PIN
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: 'Confirmar PIN',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final pin = pinController.text;
                  final confirm = confirmController.text;

                  // Validamos que el PIN tenga 6 dígitos
                  if (pin.length != 6) {
                    _showError('El PIN debe tener 6 dígitos');
                    return;
                  }
                  // Validamos que los PINs coincidan
                  if (pin != confirm) {
                    _showError('Los PINs no coinciden');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
                child: const Text('Guardar PIN'),
              ),
            ],
          );
        },
      );

      // Si el usuario puso un PIN válido, lo guardamos
      if (result == true) {
        final pin = pinController.text.trim();
        // Convertimos el PIN a hash SHA-256
        final hash = sha256.convert(utf8.encode(pin)).toString();
        await categoryProvider.setCategoryPassword(categoryName, hash);

        _showSuccess('Carpeta "$categoryName" protegida con PIN');
        setState(() {});
      }
    }
  }

  Future<void> _recoverPinWithLoginPassword({
    required String categoryName,
    required CategoryProvider categoryProvider,
    required bool isDarkMode,
  }) async {
    // Obtenemos el usuario actual
    final currentUser = _supabase.auth.currentUser;
    final String? userEmail = currentUser?.email;

    // Verificamos que hay un usuario autenticado
    if (currentUser == null || userEmail == null || userEmail.isEmpty) {
      _showError('No se pudo verificar la cuenta. Inicia sesión nuevamente.');
      return;
    }

    final TextEditingController passwordController = TextEditingController();

    // Pedimos la contraseña de inicio de sesión
    final bool? passwordOk = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Color de fondo según el tema
        Color colorFondo;
        if (isDarkMode == true) {
          colorFondo = cardDark;
        } else {
          colorFondo = Colors.white;
        }

        return AlertDialog(
          backgroundColor: colorFondo,
          title: const Text('Verificar identidad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Introduce tu contraseña de inicio de sesión:'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Contraseña de tu cuenta',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: pinkPrimary, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text.trim();

                if (password.isEmpty) {
                  _showError('Debes ingresar tu contraseña');
                  return;
                }
                if (password.length < 6) {
                  _showError('La contraseña debe tener al menos 6 caracteres');
                  return;
                }

                try {
                  // Verificamos la contraseña con Supabase
                  await _supabase.auth.signInWithPassword(
                    email: userEmail,
                    password: password,
                  );

                  if (mounted == true) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  _showError('Contraseña de inicio de sesión incorrecta');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
              child: const Text('Verificar'),
            ),
          ],
        );
      },
    );

    // Si la contraseña es incorrecta, salimos
    if (passwordOk != true) {
      return;
    }

    // Controladores para el nuevo PIN
    final TextEditingController newPinController = TextEditingController();
    final TextEditingController confirmPinController = TextEditingController();

    // Pedimos el nuevo PIN
    final bool? changeOk = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Color de fondo según el tema
        Color colorFondo;
        if (isDarkMode == true) {
          colorFondo = cardDark;
        } else {
          colorFondo = Colors.white;
        }

        return AlertDialog(
          backgroundColor: colorFondo,
          title: const Text('Cambiar PIN de carpeta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nueva contraseña PIN para "$categoryName"'),
              const SizedBox(height: 16),
              // Campo para el nuevo PIN
              TextField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: 'Nuevo PIN',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Campo para confirmar el nuevo PIN
              TextField(
                controller: confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: 'Confirmar nuevo PIN',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final newPin = newPinController.text;
                final confirmPin = confirmPinController.text;

                // Validamos que el PIN tenga 6 dígitos
                if (newPin.length != 6) {
                  _showError('El PIN debe tener 6 dígitos');
                  return;
                }
                // Validamos que los PINs coincidan
                if (newPin != confirmPin) {
                  _showError('Los PINs no coinciden');
                  return;
                }

                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
              child: const Text('Cambiar PIN'),
            ),
          ],
        );
      },
    );

    // Si el usuario puso un PIN válido, lo guardamos
    if (changeOk == true) {
      // Convertimos el PIN a hash SHA-256
      final hash = sha256.convert(utf8.encode(newPinController.text)).toString();
      await categoryProvider.setCategoryPassword(categoryName, hash);
      _showSuccess('PIN actualizado para "$categoryName"');

      if (mounted == true) {
        setState(() {});
      }
    }
  }

  Future<void> _showRestoreDialog() async {
    // Obtenemos el tema para saber si es modo oscuro
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Mostramos diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        // Color de fondo según el tema
        Color colorFondo;
        if (isDarkMode == true) {
          colorFondo = cardDark;
        } else {
          colorFondo = Colors.white;
        }

        return AlertDialog(
          backgroundColor: colorFondo,
          title: const Text('Restaurar Carpetas Predeterminadas'),
          content: const Text(
            '¿Quieres restaurar las carpetas predeterminadas?\n\n'
            'Esto añadirá: Viajes, Amigos, Familia, Comida, Estudio\n\n'
            'Además, no se eliminarán tus carpetas personalizadas',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkPrimary,
              ),
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    );

    // Si el usuario confirmó, restauramos las carpetas
    if (confirm == true) {
      // Mostramos el círculo de carga
      setState(() {
        _isLoading = true;
      });

      try {
        final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
        await categoryProvider.restoreDefaultCategories();
        _showSuccess('Carpetas predeterminadas restauradas');
      } catch (e) {
        _showError('Error al restaurar: $e');
      } finally {
        // Ocultamos el círculo de carga
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
