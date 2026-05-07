import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/media/image_upload_service.dart';
import '../../../../core/ui/app_sections.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/profile_controller.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _initialized = false;
  String? _avatarUrl;
  File? _selectedAvatarFile;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImageUploadService().pickImageFromGallery();
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedAvatarFile = File(picked.path);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;

    if (!_initialized && profile != null) {
      _nameController.text = profile.name;
      _bioController.text = profile.bio;
      _avatarUrl = profile.avatarUrl;
      _initialized = true;
    }

    final ImageProvider<Object>? avatarProvider = _selectedAvatarFile != null
        ? FileImage(_selectedAvatarFile!)
        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
              ? NetworkImage(_avatarUrl!)
              : null);

    return Scaffold(
      appBar: AppBar(),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      const AppPageHeader(
                        title: 'Редактирование профиля',
                        subtitle:
                            'Обновите имя, описание и аватар, чтобы соседям было легче узнать вас и доверять вам.',
                      ),
                      const SizedBox(height: 16),
                      AppSectionCard(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundImage: avatarProvider,
                              child: avatarProvider == null
                                  ? Text(
                                      _nameController.text.trim().isEmpty
                                          ? '?'
                                          : _nameController.text
                                                .trim()
                                                .substring(0, 1)
                                                .toUpperCase(),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: state.loading || _uploadingImage
                                      ? null
                                      : _pickAvatar,
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Выбрать из галереи'),
                                ),
                                if (_selectedAvatarFile != null ||
                                    (_avatarUrl != null &&
                                        _avatarUrl!.isNotEmpty))
                                  TextButton(
                                    onPressed: state.loading || _uploadingImage
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedAvatarFile = null;
                                              _avatarUrl = null;
                                            });
                                          },
                                    child: const Text('Убрать'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Имя пользователя',
                              ),
                              validator: Validators.name,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _bioController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Краткое описание',
                              ),
                              validator: Validators.profileBio,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (state.error != null) ...[
                        Text(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton(
                        onPressed: state.loading || _uploadingImage
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }

                                String? avatarUrl = _avatarUrl;
                                if (_selectedAvatarFile != null) {
                                  setState(() {
                                    _uploadingImage = true;
                                  });
                                  try {
                                    avatarUrl = await ImageUploadService()
                                        .uploadImage(
                                          file: XFile(
                                            _selectedAvatarFile!.path,
                                          ),
                                          folder: 'avatars',
                                        );
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(mapAppError(e))),
                                      );
                                    }
                                    if (mounted) {
                                      setState(() {
                                        _uploadingImage = false;
                                        _selectedAvatarFile = null;
                                      });
                                    }
                                    avatarUrl = _avatarUrl;
                                  }
                                  if (mounted) {
                                    setState(() {
                                      _uploadingImage = false;
                                      _avatarUrl = avatarUrl;
                                    });
                                  }
                                }

                                final success = await ref
                                    .read(profileControllerProvider.notifier)
                                    .updateProfile(
                                      name: _nameController.text,
                                      bio: _bioController.text,
                                      avatarUrl: avatarUrl,
                                    );

                                if (!context.mounted) {
                                  return;
                                }

                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Профиль обновлён'),
                                    ),
                                  );
                                  context.pop();
                                }
                              },
                        child: state.loading || _uploadingImage
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Сохранить'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
