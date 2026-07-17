import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'director_song_delivery_screen.dart';

/// The launcher widget is deliberately restricted to directors. Admin work
/// remains in the normal Admin area, keeping song distribution role-specific.
class DirectorWidgetEntryScreen extends StatefulWidget {
  const DirectorWidgetEntryScreen({super.key});

  @override
  State<DirectorWidgetEntryScreen> createState() =>
      _DirectorWidgetEntryScreenState();
}

class _DirectorWidgetEntryScreenState extends State<DirectorWidgetEntryScreen> {
  late Future<StaffRole> _role = AuthService().currentStaffRole();

  void _retry() => setState(() => _role = AuthService().currentStaffRole());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StaffRole>(
      future: _role,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == StaffRole.director) {
          return const DirectorSongDeliveryScreen();
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Creat Noti')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 52,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Director access required',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Creat Noti is available only to the director role. Members cannot use this widget.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Check role again'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Return to Noti'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
