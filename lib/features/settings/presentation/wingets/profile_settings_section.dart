import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

class ProfileSettingsSection extends ConsumerWidget {
  const ProfileSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    final user = authState.user;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final name = user.name?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Profile',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 10),

        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _ProfileAvatar(
                  name: name,
                  avatarUrl: user.avatarUrl,
                  radius: 30,
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null || name.isEmpty ? 'Linsy user' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),

                      if (user.email != null && user.email!.isNotEmpty) ...[
                        const SizedBox(height: 3),

                        Text(
                          user.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                IconButton.filledTonal(
                  tooltip: 'Edit profile',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// EDIT PROFILE PAGE
// =====================================================================

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _nameController;

  late final String _initialName;

  Uint8List? _avatarBytes;

  String? _avatarContentType;

  bool _saving = false;
  bool _pickingAvatar = false;

  // ===================================================================
  // CHANGES
  // ===================================================================

  bool get _hasChanges {
    final currentName = _nameController.text.trim();

    final nameChanged = currentName != _initialName;

    final avatarChanged = _avatarBytes != null;

    return nameChanged || avatarChanged;
  }

  bool get _canSave {
    final displayName = _nameController.text.trim();

    if (_saving || _pickingAvatar) {
      return false;
    }

    if (displayName.isEmpty) {
      return false;
    }

    if (displayName.length > 40) {
      return false;
    }

    return _hasChanges;
  }

  // ===================================================================
  // INIT
  // ===================================================================

  @override
  void initState() {
    super.initState();

    final user = ref.read(authControllerProvider).user;

    _initialName = user?.name?.trim() ?? '';

    _nameController = TextEditingController(text: _initialName);

    _nameController.addListener(_handleFormChanged);
  }

  // ===================================================================
  // FORM CHANGED
  // ===================================================================

  void _handleFormChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  @override
  void dispose() {
    _nameController.removeListener(_handleFormChanged);

    _nameController.dispose();

    super.dispose();
  }

  // ===================================================================
  // PICK AVATAR
  // ===================================================================

  Future<void> _pickAvatar() async {
    if (_pickingAvatar || _saving) {
      return;
    }

    setState(() {
      _pickingAvatar = true;
    });

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();

      const maxSize = 5 * 1024 * 1024;

      if (bytes.lengthInBytes > maxSize) {
        if (!mounted) {
          return;
        }

        _showMessage('Avatar must be smaller than 5 MB.');

        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _avatarBytes = bytes;

        _avatarContentType =
            picked.mimeType ?? _contentTypeFromFileName(picked.name);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Failed to select image: $error');
    } finally {
      if (mounted) {
        setState(() {
          _pickingAvatar = false;
        });
      }
    }
  }

  // ===================================================================
  // SAVE
  // ===================================================================

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }

    final displayName = _nameController.text.trim();

    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            displayName: displayName,
            avatarBytes: _avatarBytes,
            avatarContentType: _avatarContentType,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Failed to update profile: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ===================================================================
  // MESSAGE
  // ===================================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You are not signed in.')),
      );
    }

    return Scaffold(
      // =================================================================
      // APP BAR
      // =================================================================
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton.icon(
            onPressed: _canSave ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save'),
          ),

          const SizedBox(width: 8),
        ],
      ),

      // =================================================================
      // BODY
      // =================================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // =====================================================
                  // AVATAR
                  // =====================================================
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _EditableAvatar(
                          name: _nameController.text,
                          avatarUrl: user.avatarUrl,
                          avatarBytes: _avatarBytes,
                        ),

                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: IconButton.filled(
                            tooltip: 'Choose avatar',
                            onPressed: _pickingAvatar || _saving
                                ? null
                                : _pickAvatar,
                            icon: _pickingAvatar
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =====================================================
                  // NAME
                  // =====================================================
                  TextField(
                    controller: _nameController,
                    maxLength: 40,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_canSave) {
                        _save();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // =====================================================
                  // EMAIL
                  // =====================================================
                  TextField(
                    controller: TextEditingController(text: user.email ?? ''),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      suffixIcon: Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(),
                      helperText: 'Email changes are not available here yet.',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =====================================================
                  // SAVE
                  // =====================================================
                  FilledButton.icon(
                    onPressed: _canSave ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Save changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// EDITABLE AVATAR
// =====================================================================

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.name,
    required this.avatarUrl,
    required this.avatarBytes,
  });

  final String? name;
  final String? avatarUrl;
  final Uint8List? avatarBytes;

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? imageProvider;

    if (avatarBytes != null) {
      imageProvider = MemoryImage(avatarBytes!);
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(avatarUrl!);
    }

    return CircleAvatar(
      radius: 54,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              _initial(name),
              style: Theme.of(context).textTheme.headlineMedium,
            )
          : null,
    );
  }
}

// =====================================================================
// PROFILE AVATAR
// =====================================================================

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.avatarUrl,
    required this.radius,
  });

  final String? name;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
      child: hasAvatar
          ? null
          : Text(_initial(name), style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

// =====================================================================
// HELPERS
// =====================================================================

String _initial(String? name) {
  final value = name?.trim() ?? '';

  if (value.isEmpty) {
    return '?';
  }

  return value.substring(0, 1).toUpperCase();
}

String _contentTypeFromFileName(String fileName) {
  final lower = fileName.toLowerCase();

  if (lower.endsWith('.png')) {
    return 'image/png';
  }

  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }

  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }

  return 'image/jpeg';
}
