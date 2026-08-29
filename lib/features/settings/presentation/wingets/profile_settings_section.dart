import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/application/profile_store.dart';

class ProfileSettingsSection extends ConsumerWidget {
  const ProfileSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth отвечает только за identity / session / email.
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return const SizedBox.shrink();
    }

    // Имя и avatar всегда берём из ProfileStore.
    final profile = ref.watch(profileByIdProvider(user.id));

    final rawName = profile?.displayName?.trim();

    final displayName = rawName != null && rawName.isNotEmpty
        ? rawName
        : 'Linsy user';

    final avatarUrl = profile?.avatarUrl;

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
                  name: displayName,
                  avatarUrl: avatarUrl,
                  radius: 30,
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
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

  Uint8List? _avatarBytes;
  String? _avatarContentType;

  bool _saving = false;
  bool _pickingAvatar = false;

  // ===================================================================
  // ORIGINAL STATE / DIRTY STATE
  // ===================================================================

  String _originalDisplayName = '';

  bool _profileInitialized = false;

  bool _profileInitializationScheduled = false;

  bool _nameEditedByUser = false;

  bool _suppressNameListener = false;

  bool get _hasValidName {
    final name = _nameController.text.trim();

    return name.isNotEmpty && name.length <= 40;
  }

  bool get _hasChanges {
    if (!_profileInitialized) {
      return false;
    }

    final currentName = _nameController.text.trim();

    final nameChanged = currentName != _originalDisplayName;

    final avatarChanged = _avatarBytes != null;

    return nameChanged || avatarChanged;
  }

  bool get _canSave {
    return !_saving &&
        !_pickingAvatar &&
        _profileInitialized &&
        _hasValidName &&
        _hasChanges;
  }

  // ===================================================================
  // INIT
  // ===================================================================

  @override
  void initState() {
    super.initState();

    final user = ref.read(authControllerProvider).user;

    final cachedProfile = user == null
        ? null
        : ref.read(profileStoreProvider)[user.id];

    final initialName = cachedProfile?.displayName?.trim() ?? '';

    _originalDisplayName = initialName;

    _profileInitialized = cachedProfile != null;

    _nameController = TextEditingController(text: initialName);

    _nameController.addListener(_handleNameChanged);
  }

  // ===================================================================
  // DISPOSE
  // ===================================================================

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);

    _nameController.dispose();

    super.dispose();
  }

  // ===================================================================
  // NAME CHANGED
  // ===================================================================

  void _handleNameChanged() {
    if (_suppressNameListener) {
      return;
    }

    _nameEditedByUser = true;

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ===================================================================
  // INITIALIZE PROFILE AFTER LAZY LOAD
  // ===================================================================

  void _scheduleProfileInitialization(String loadedName) {
    if (_profileInitialized || _profileInitializationScheduled) {
      return;
    }

    _profileInitializationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _profileInitialized) {
        return;
      }

      _suppressNameListener = true;

      try {
        // Если пользователь уже начал вводить имя до завершения
        // lazy-load профиля — его текст НЕ перетираем.
        if (!_nameEditedByUser) {
          _nameController.value = TextEditingValue(
            text: loadedName,
            selection: TextSelection.collapsed(offset: loadedName.length),
          );
        }
      } finally {
        _suppressNameListener = false;
      }

      setState(() {
        _originalDisplayName = loadedName;

        _profileInitialized = true;

        _profileInitializationScheduled = false;
      });
    });
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

    final user = ref.read(authControllerProvider).user;

    if (user == null) {
      _showMessage('You are not signed in.');

      return;
    }

    final displayName = _nameController.text.trim();

    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(profileStoreProvider.notifier)
          .updateProfile(
            userId: user.id,
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

    final profile = ref.watch(profileByIdProvider(user.id));

    // ProfileStore lazy-load.
    //
    // Если профиль уже был в кеше — всё было инициализировано
    // ещё в initState().
    //
    // Если нет — спокойно ждём его здесь.
    if (!_profileInitialized && profile != null) {
      _scheduleProfileInitialization(profile.displayName?.trim() ?? '');
    }

    final avatarUrl = profile?.avatarUrl;

    return Scaffold(
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

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===================================================
                  // AVATAR
                  // ===================================================
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _EditableAvatar(
                          name: _nameController.text,
                          avatarUrl: avatarUrl,
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

                  // ===================================================
                  // NAME
                  // ===================================================
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

                  // ===================================================
                  // EMAIL
                  // ===================================================
                  TextFormField(
                    initialValue: user.email ?? '',
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

                  // ===================================================
                  // SAVE
                  // ===================================================
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
