import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';

class AdminEntryScreen extends StatelessWidget {
  const AdminEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AdminStatusScreen(
            message: 'Checking your admin session...',
          );
        }

        if (snapshot.hasError) {
          return _AdminAccessIssueScreen(
            message: 'Noti could not read the admin session. Please try again.',
            onRetry: () => FirebaseAuth.instance.currentUser?.reload(),
          );
        }

        final user = snapshot.data;
        if (user == null || user.isAnonymous) {
          return const AdminLoginScreen();
        }

        // Keep the Firestore role check stable across theme and navigation rebuilds.
        return _AdminAuthorizationGate(
          key: ValueKey(user.uid),
          userId: user.uid,
        );
      },
    );
  }
}

class _AdminAuthorizationGate extends StatefulWidget {
  const _AdminAuthorizationGate({super.key, required this.userId});

  final String userId;

  @override
  State<_AdminAuthorizationGate> createState() =>
      _AdminAuthorizationGateState();
}

class _AdminAuthorizationGateState extends State<_AdminAuthorizationGate> {
  late Future<bool> _authorization;

  @override
  void initState() {
    super.initState();
    _authorization = _checkAuthorization();
  }

  Future<bool> _checkAuthorization() => AuthService().isCurrentUserAdmin();

  void _retry() {
    setState(() => _authorization = _checkAuthorization());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authorization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AdminStatusScreen(
            message: 'Confirming administrator access...',
          );
        }

        if (snapshot.hasError) {
          return _AdminAccessIssueScreen(
            message:
                'Noti could not verify administrator access. Check your connection and try again.',
            onRetry: _retry,
          );
        }

        if (snapshot.data == true) {
          return const AdminDashboardScreen();
        }

        return const _AdminAccessDeniedScreen();
      },
    );
  }
}

class _AdminStatusScreen extends StatelessWidget {
  const _AdminStatusScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AdminAccessIssueScreen extends StatelessWidget {
  const _AdminAccessIssueScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin access')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 44),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                TextButton(
                  onPressed: () => AuthService().signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAccessDeniedScreen extends StatelessWidget {
  const _AdminAccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin access')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 40),
                const SizedBox(height: 16),
                Text(
                  'This account is not an authorized Noti administrator.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => AuthService().signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
