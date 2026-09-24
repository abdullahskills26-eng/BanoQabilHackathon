import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../services/firestore_service.dart';
import '../../../services/supabase_storage_service.dart';

/// Shared profile screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  late Future<Map<String, dynamic>> _future;
  bool _saving = false;

  /// Supabase storage path of the current picture, and a short-lived signed
  /// URL for displaying it. The bucket is private, so the URL is minted on
  /// read and never persisted.
  String? _photoPath;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final uid = FirebaseService.currentUid;
    final doc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();
    final data = doc.data() ?? {};
    _name.text = (data['name'] ?? '').toString();
    _phone.text = (data['phone'] ?? '').toString();

    // `photoPath` is the Supabase object path. Sign it for display; on
    // failure fall back to the initial-letter avatar rather than erroring.
    _photoPath = (data['photoPath'] ?? '').toString();
    _photoUrl = await SupabaseStorageService.signedUrlOrNull(_photoPath);

    return {...data, 'uid': uid};
  }

  /// Picks an image, uploads it to Supabase, then records only the path in
  /// Firestore. The existing picture is kept if anything fails.
  Future<void> _changePhoto() async {
    final previousPath = _photoPath;

    setState(() {
      _uploadingPhoto = true;
      _photoError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true, // required on web: bytes, not a path
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _uploadingPhoto = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Could not read that image.');
      }

      final uid = FirebaseService.currentUid;
      final stored = await SupabaseStorageService.uploadProfilePicture(
        uid: uid,
        bytes: bytes,
        fileName: file.name,
      );

      // Store the path and metadata only — never the image bytes.
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set({
        'photoPath': stored.path,
        'photoFileName': stored.fileName,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final url = await SupabaseStorageService.signedUrlOrNull(stored.path);

      // A replaced picture with a different extension leaves the old object
      // behind; clean it up, but never fail the update over it.
      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != stored.path) {
        await SupabaseStorageService.deleteQuietly(previousPath);
      }

      if (!mounted) return;
      setState(() {
        _photoPath = stored.path;
        _photoUrl = url;
        _uploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _photoError = e.toString();
      });
    }
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(FirebaseService.currentUid)
          .set({'name': _name.text.trim(), 'phone': _phone.text.trim()},
              SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingState(message: 'Loading profile…');
            }
            if (snap.hasError) {
              return ErrorRetry(
                  message: snap.error.toString(), onRetry: _reload);
            }

            final data = snap.data!;
            final name = _name.text.isEmpty ? 'Your profile' : _name.text;
            final email = (data['email'] ??
                    FirebaseAuth.instance.currentUser?.email ??
                    '')
                .toString();

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    AccentCard(
                      accent: AppColors.primary,
                      accentSoft: AppColors.primarySoft,
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        children: [
                          _AvatarPicker(
                            name: name,
                            photoUrl: _photoUrl,
                            uploading: _uploadingPhoto,
                            onTap: _uploadingPhoto ? null : _changePhoto,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontSize: 20)),
                                const SizedBox(height: 3),
                                Text(email,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                                if ((data['role'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                          AppColors.radiusPill),
                                    ),
                                    child: Text(
                                      data['role'].toString().toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_photoError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusField),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.28)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Picture not changed. $_photoError',
                                style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12.5,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit details',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _name,
                            label: 'Name',
                            prefixIcon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 14),
                          CustomTextField(
                            controller: _phone,
                            label: 'Phone',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 18),
                          CustomButton(
                            label: 'Save profile',
                            icon: Icons.save_outlined,
                            expand: true,
                            isLoading: _saving,
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Campus',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 14),
                          _Row(
                              label: 'City',
                              value: (data['city'] ?? '—').toString()),
                          _Row(
                              label: 'Campus',
                              value: (data['campus'] ??
                                      data['campusName'] ??
                                      '—')
                                  .toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    CustomButton.outlined(
                      label: 'Log out',
                      icon: Icons.logout,
                      expand: true,
                      onPressed: _logout,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Avatar that doubles as the upload button.
///
/// Falls back to the user's initial whenever there is no picture, the signed
/// URL could not be minted, or the image fails to load.
class _AvatarPicker extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool uploading;
  final VoidCallback? onTap;

  const _AvatarPicker({
    required this.name,
    required this.photoUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Tooltip(
      message: 'Change profile picture',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              foregroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
              // Keeps the initial visible if the network image 404s or the
              // signed URL has expired.
              onForegroundImageError:
                  hasPhoto ? (error, stack) {} : null,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 24),
              ),
            ),
            if (uploading)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  ),
                ),
              )
            else
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13.5)),
        ],
      ),
    );
  }
}
