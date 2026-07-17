import 'package:flutter/material.dart';

Future<String?> showOrganizationPinDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Organization PIN'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        maxLength: 6,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Enter the 6-digit organization PIN',
          prefixIcon: Icon(Icons.password_rounded),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final pin = controller.text.trim();
            if (!RegExp(r'^\d{6}$').hasMatch(pin)) return;
            Navigator.pop(dialogContext, pin);
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
