import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialName;
  final DateTime? initialBirthday;
  final String? initialPhotoUrl;
  final String? initialBio;

  const EditProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialBirthday,
    this.initialPhotoUrl,
    this.initialBio,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  DateTime? _birthday;
  String? _photoUrl;
  bool _uploading = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _bioController = TextEditingController(text: widget.initialBio ?? '');
    _birthday = widget.initialBirthday;
    _photoUrl = widget.initialPhotoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final firstDate = DateTime(1900, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);

    final selected = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select birthday',
    );
    if (selected != null) {
      setState(() => _birthday = selected);
    }
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  int _ageFrom(DateTime d) {
    final today = DateTime.now();
    int age = today.year - d.year;
    if (today.month < d.month || (today.month == d.month && today.day < d.day)) {
      age--;
    }
    return age;
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }
    Navigator.pop(context, {
      'name': name,
      'birthday': _birthday?.toIso8601String(),
      'photoUrl': _photoUrl,
      'bio': _bioController.text.trim(),
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_picking || _uploading) return; // prevent re-entrancy / double taps
    try {
      setState(() { _picking = true; });
      if (widget.userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to update your photo.')),
        );
        return;
      }
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
      if (picked == null) return;
      setState(() => _uploading = true);

      try {
        final fileBytes = await picked.readAsBytes();
        final storageRef = FirebaseStorage.instance.ref().child('avatars/${widget.userId}/profile.jpg');
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        final task = await storageRef.putData(fileBytes, metadata);
        // Retry getDownloadURL to avoid transient 'object-not-found' right after upload
        Future<String> _retryGetUrl(Reference ref, {int attempts = 5}) async {
          FirebaseException? lastErr;
          for (int i = 0; i < attempts; i++) {
            try {
              return await ref.getDownloadURL();
            } on FirebaseException catch (e) {
              lastErr = e;
              if (e.code != 'object-not-found') break; // only retry on object-not-found
              await Future.delayed(Duration(milliseconds: 250 * (i + 1)));
            }
          }
          throw lastErr ?? FirebaseException(plugin: 'storage', code: 'unknown');
        }
        if (task.state != TaskState.success) {
          throw FirebaseException(plugin: 'storage', code: 'upload-failed');
        }
        final url = await _retryGetUrl(storageRef);

        if (!mounted) return;
        setState(() {
          _photoUrl = url;
          _uploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      } on FirebaseException catch (_) {
        // Fallback: save locally if Storage isn't available
        final localPath = await _saveAvatarLocally(picked);
        if (!mounted) return;
        setState(() {
          _photoUrl = localPath; // file://...
          _uploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo saved locally')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      final msg = e is FirebaseException ? 'Failed to update photo: ${e.code}' : 'Failed to update photo: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) {
        setState(() { _picking = false; });
      }
    }
  }

  Future<String> _saveAvatarLocally(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${dir.path}/avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }
    final file = File('${avatarsDir.path}/profile.jpg');
    await file.writeAsBytes(await picked.readAsBytes(), flush: true);
    return 'file://${file.path}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar (with upload)
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
                        ? const Icon(Icons.person, size: 48, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: (_uploading || _picking) ? null : _pickAndUploadAvatar,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: (_uploading || _picking)
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name
            Text('Name', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),

            const SizedBox(height: 16),

            // Birthday
            Text('Birthday', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickBirthday,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_birthday != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(_birthday!)),
                          const SizedBox(height: 2),
                          Text('Age ${_ageFrom(_birthday!)}', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      )
                    else
                      Text('Tap to select your birthday', style: TextStyle(color: Colors.grey.shade600)),
                    const Icon(Icons.cake_outlined)
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
