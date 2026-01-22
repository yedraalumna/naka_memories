import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../constants/colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Con esto cambiamos la contraseña usando AppAuthProvider
  Future<void> _changePassword() async {
    if (_newPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, ingresa una nueva contraseña';
      });
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(() {
        _errorMessage = 'La contraseña debe tener al menos 6 caracteres';
      });
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Las contraseñas no coinciden';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await authProvider.changePassword(_newPasswordController.text);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña cambiada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Volvemos a la pantalla atrás después de cambiar la contraseña
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Error al cambiar la contraseña';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error desconocido: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cambiar Contraseña'),
        backgroundColor: pinkPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: pinkDark,
                  ),
                ),

                const SizedBox(height: 30),

                // Información importante
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pinkLighter,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: pinkPrimary, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: pinkPrimary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'La nueva contraseña debe tener al menos 6 caracteres',
                          style: TextStyle(color: pinkDark),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Campo para nueva contraseña
                TextField(
                  controller: _newPasswordController,
                  obscureText: !_showNewPassword,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock, color: pinkPrimary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNewPassword ? Icons.visibility : Icons.visibility_off,
                        color: pinkPrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showNewPassword = !_showNewPassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Campo para confirmar contraseña
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_showConfirmPassword,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_reset, color: pinkPrimary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: pinkPrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),

                // Mensaje de error
                if (_errorMessage != null) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Guardar'),
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
}