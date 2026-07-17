import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../widgets/adaptive_page_body.dart';
import 'admin_entry_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final TextEditingController _firstNameController;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _initializedFromProfile = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: _firstName(FirebaseAuth.instance.currentUser?.displayName),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    super.dispose();
  }

  String _firstName(String? displayName) {
    final trimmed = displayName?.trim() ?? '';
    return trimmed.isEmpty ? '' : trimmed.split(RegExp(r'\s+')).first;
  }

  String _profileInitial({String? displayName, String? email}) {
    final name = _firstName(displayName);
    if (name.isNotEmpty) return name[0].toUpperCase();

    final trimmedEmail = email?.trim() ?? '';
    if (trimmedEmail.isNotEmpty) return trimmedEmail[0].toUpperCase();

    return 'N';
  }

  Future<void> _saveFirstName() async {
    final firstName = _firstNameController.text.trim();
    if (firstName.isEmpty || firstName.length > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a first name of up to 40 characters.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await AuthService().updateDirectorProfile(firstName: firstName);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('First name saved.')));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not save your first name.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your first name: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final firstName = _firstNameController.text.trim();
    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save your first name before adding a picture.'),
        ),
      );
      return;
    }
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 320,
      maxHeight: 320,
      imageQuality: 72,
    );
    if (image == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await image.readAsBytes();
      final photoBase64 = base64Encode(bytes);
      final ref = FirebaseStorage.instance.ref(
        'profile_pictures/${user.uid}.jpg',
      );
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final photoUrl = await ref.getDownloadURL();
      await AuthService().updateDirectorProfile(
        firstName: firstName,
        photoUrl: photoUrl,
        photoBase64: photoBase64,
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture saved.')));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not save the profile picture.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the profile picture: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminEntryScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colors = Theme.of(context).colorScheme;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff Profile')),
        body: const Center(child: Text('No director session is active.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final profile = snapshot.data?.data() ?? const <String, dynamic>{};
          final profileDisplayName =
              (profile['displayName'] as String?)?.trim() ?? '';
          final profilePhotoBase64 =
              (profile['photoBase64'] as String?)?.trim() ?? '';
          final profilePhotoUrl =
              (profile['photoURL'] as String?)?.trim() ?? '';

          if (!_initializedFromProfile && profileDisplayName.isNotEmpty) {
            _firstNameController.text = _firstName(profileDisplayName);
            _initializedFromProfile = true;
          }

          final photoBytes = profilePhotoBase64.isNotEmpty
              ? base64Decode(profilePhotoBase64)
              : null;

          return AdaptivePageBody(
            maxWidth: 560,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: colors.primaryContainer,
                              foregroundColor: colors.primary,
                              backgroundImage: photoBytes != null
                                  ? MemoryImage(photoBytes)
                                  : (profilePhotoUrl.isNotEmpty
                                        ? NetworkImage(profilePhotoUrl)
                                        : null),
                              child:
                                  photoBytes != null ||
                                      profilePhotoUrl.isNotEmpty
                                  ? null
                                  : Text(
                                      _profileInitial(
                                        displayName:
                                            profileDisplayName.isNotEmpty
                                            ? profileDisplayName
                                            : user.displayName,
                                        email: user.email,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: -8,
                              bottom: -4,
                              child: IconButton.filledTonal(
                                tooltip: 'Change profile picture',
                                onPressed: _uploadingPhoto
                                    ? null
                                    : _changeProfilePhoto,
                                icon: _uploadingPhoto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.photo_camera_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.email ?? 'Unknown admin',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profileDisplayName.isNotEmpty
                              ? profileDisplayName
                              : (user.displayName?.isNotEmpty == true
                                    ? user.displayName!
                                    : 'Firebase authenticated staff member'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 40,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                            hintText: 'How should Noti greet you?',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          onSubmitted: (_) => _saving ? null : _saveFirstName(),
                        ),
                        const SizedBox(height: 4),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveFirstName,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _saving ? 'Saving...' : 'Save first name',
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: () => _signOut(context),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
