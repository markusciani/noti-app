import 'package:flutter/material.dart';

import '../models/organization.dart';
import '../services/founder_service.dart';
import '../services/organization_service.dart';
import '../widgets/adaptive_page_body.dart';

class FounderStaffScreen extends StatefulWidget {
  const FounderStaffScreen({super.key});

  @override
  State<FounderStaffScreen> createState() => _FounderStaffScreenState();
}

class _FounderStaffScreenState extends State<FounderStaffScreen> {
  final _founderService = FounderService();
  final _organizationService = OrganizationService();
  late Future<List<FounderAuthUser>> _usersFuture;
  late Future<List<Organization>> _organizationsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _usersFuture = _founderService.listAuthUsers();
    _organizationsFuture = _organizationService.getAvailableOrganizations();
  }

  Future<void> _editUser(
    BuildContext context,
    FounderAuthUser user,
    List<Organization> organizations,
  ) async {
    if (user.isFounder) return;
    var role = user.role == 'director' ? 'director' : 'admin';
    var enabled = user.enabled && !user.disabled;
    var organizationId =
        organizations.any(
          (organization) => organization.id == user.organizationId,
        )
        ? user.organizationId
        : organizations.first.id;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user.email.isEmpty ? 'Staff account' : user.email),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'director', child: Text('Director')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => role = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: organizationId,
                decoration: const InputDecoration(labelText: 'Organization'),
                items: organizations
                    .map(
                      (organization) => DropdownMenuItem(
                        value: organization.id,
                        child: Text(organization.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => organizationId = value);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save role'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await _founderService.setStaffProfile(
        uid: user.uid,
        role: role,
        organizationId: organizationId,
        enabled: enabled,
      );
      if (!context.mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Staff access updated.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update staff access: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff access')),
      body: FutureBuilder<List<Organization>>(
        future: _organizationsFuture,
        builder: (context, organizationSnapshot) {
          if (organizationSnapshot.hasError) {
            return Center(child: Text('Could not load organizations.'));
          }
          if (!organizationSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final organizations = organizationSnapshot.data!;
          return FutureBuilder<List<FounderAuthUser>>(
            future: _usersFuture,
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load Firebase accounts: ${userSnapshot.error}',
                    ),
                  ),
                );
              }
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = userSnapshot.data!;
              return AdaptivePageBody(
                maxWidth: 900,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Firebase accounts',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose an existing Firebase Authentication account and assign it to an organization as an admin or director. This fixes the common case where an account exists in Firebase Auth but has no users profile yet.',
                    ),
                    const SizedBox(height: 16),
                    ...users.map(
                      (user) => Card(
                        child: ListTile(
                          leading: Icon(
                            user.isFounder
                                ? Icons.workspace_premium_rounded
                                : user.role == 'director'
                                ? Icons.library_music_rounded
                                : Icons.person_rounded,
                          ),
                          title: Text(
                            user.email.isEmpty ? user.uid : user.email,
                          ),
                          subtitle: Text(
                            user.isFounder
                                ? 'FOUNDER'
                                : '${user.role.isEmpty ? 'Not assigned' : user.role.toUpperCase()} • ${user.enabled ? 'Enabled' : 'Disabled'} • ${user.organizationId}',
                          ),
                          trailing: user.isFounder
                              ? const Chip(label: Text('Founder'))
                              : IconButton(
                                  tooltip: 'Assign role',
                                  onPressed: () =>
                                      _editUser(context, user, organizations),
                                  icon: const Icon(Icons.edit_rounded),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
