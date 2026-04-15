import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../constants/colors.dart';

/// Diálogo para pedir PIN de 6 dígitos y verificar acceso a carpeta protegida
class PinDialog extends StatefulWidget {
  final String correctHash;   // Hash del PIN correcto
  final String? titulo;       // Título opcional

  const PinDialog({
    super.key,
    required this.correctHash,
    this.titulo,
  });

  @override
  State<PinDialog> createState() {
    return _PinDialogState();
  }
}

class _PinDialogState extends State<PinDialog> {
  final TextEditingController controller = TextEditingController();
  String errorMessage = "";
  bool isVerifying = false;

  // Liberamos los recursos al cerrar
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Verificamos si el PIN es correcto
  void _verifyPin(String pin) async {
    if (isVerifying == true) return;

    setState(() {
      isVerifying = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    // Convertimos el PIN a hash SHA-256
    final hashInput = sha256.convert(utf8.encode(pin)).toString();

    if (hashInput == widget.correctHash) {
      // si el pin es correcto, cerramos devolviendo true
      if (mounted == true) {
        Navigator.pop(context, true);
      }
    } else {
      // si el pin es incorrecto, mostramos error
      if (mounted == true) {
        setState(() {
          errorMessage = "PIN incorrecto";
          isVerifying = false;
        });
        controller.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinamos el título
    String tituloDialogo;
    if (widget.titulo != null) {
      tituloDialogo = widget.titulo!;
    } else {
      tituloDialogo = "Carpeta protegida";
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.lock, color: pinkPrimary, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tituloDialogo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Introduce el PIN de 6 dígitos para poder acceder", textAlign: TextAlign.center),
          const SizedBox(height: 20),
          PinCodeTextField(
            appContext: context,
            controller: controller,
            length: 6,
            obscureText: true,
            animationType: AnimationType.fade,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(8),
              fieldHeight: 50,
              fieldWidth: 35,
              activeFillColor: pinkLighter,
              selectedFillColor: Colors.white,
              inactiveFillColor: Colors.grey.shade100,
              activeColor: pinkPrimary,
              selectedColor: pinkAccent,
              inactiveColor: Colors.grey,
              errorBorderColor: Colors.red,
            ),
            cursorColor: pinkPrimary,
            enableActiveFill: true,
            autoFocus: true,
            enabled: isVerifying == false,
            onChanged: (value) {
              if (errorMessage.isNotEmpty) {
                setState(() {
                  errorMessage = "";
                });
              }
            },
            onCompleted: (value) {
              _verifyPin(value);
            },
          ),
          if (errorMessage.isNotEmpty) 
            const SizedBox(height: 10),
          if (errorMessage.isNotEmpty)
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (isVerifying == false) {
              Navigator.pop(context, false);
            }
          },
          child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      ],
    );
  }
}