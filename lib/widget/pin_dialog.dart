import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../constants/colors.dart';

class PinDialog extends StatefulWidget {
  final String correctHash;
  final String? titulo;

  const PinDialog({
    super.key,
    required this.correctHash,
    this.titulo,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final TextEditingController controller = TextEditingController();
  String errorMessage = "";
  bool isVerifying = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _verifyPin(String pin) async {
    if (isVerifying) return;

    setState(() {
      isVerifying = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    final hashInput = sha256.convert(utf8.encode(pin)).toString();

    if (hashInput == widget.correctHash) {
      // PIN correcto: cerramos devolviendo TRUE
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      // PIN incorrecto: mostramos error, NO cerramos
      if (mounted) {
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.lock, color: pinkPrimary, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.titulo ?? "Carpeta Protegida",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Introduce el PIN de 6 dígitos para acceder",
            textAlign: TextAlign.center,
          ),
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
            enabled: !isVerifying,
            onChanged: (value) {
              if (errorMessage.isNotEmpty) {
                setState(() => errorMessage = "");
              }
            },
            onCompleted: (value) {
              _verifyPin(value);
            },
          ),
          if (errorMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: isVerifying
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text(
            "Cancelar",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      ],
    );
  }
}