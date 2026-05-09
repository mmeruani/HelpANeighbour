import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/media/image_upload_service.dart';
import '../../../../core/ui/app_sections.dart';
import '../../../../core/ui/notification_bell_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../profile/domain/entities/notification_settings.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/community_member.dart';
import '../../domain/entities/community_role.dart';
import '../controllers/community_controller.dart';

class CommunitiesPage extends ConsumerWidget {
  const CommunitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщества'),
        actions: [
          const NotificationBellButton(),
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(communityControllerProvider.notifier).load(),
        child: state.loading && state.communities.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 300),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppPageHeader(
                    title: 'Локальные сообщества',
                    subtitle:
                        'Здесь начинается всё взаимодействие: создавайте сообщество для своего дома, подъезда или СНТ и переходите к запросам.',
                    trailing: Icon(
                      Icons.home_work_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: state.loading
                              ? null
                              : () => _showCreateCommunityDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Создать сообщество'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: state.loading
                              ? null
                              : () => _showJoinCommunityDialog(context, ref),
                          icon: const Icon(Icons.group_add_outlined),
                          label: const Text('Вступить по коду или ссылке'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (state.error != null && !state.loading) ...[
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.communities.isEmpty && !state.loading)
                    AppSectionCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Вы пока не состоите ни в одном сообществе',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Попробуйте обновить страницу',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...state.communities.map(
                      (community) => _CommunityCard(community: community),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CommunityCard extends ConsumerWidget {
  final Community community;

  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCreator = community.currentUserRole == CommunityRole.creator;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSectionCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      community.imageUrl != null &&
                          community.imageUrl!.isNotEmpty
                      ? NetworkImage(community.imageUrl!)
                      : null,
                  child:
                      community.imageUrl == null || community.imageUrl!.isEmpty
                      ? Text(
                          community.name.isEmpty
                              ? '?'
                              : community.name.substring(0, 1).toUpperCase(),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    community.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              community.description.isEmpty
                  ? 'Описание сообщества пока не заполнено'
                  : community.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Участников: ${community.membersCount}')),
                Chip(
                  label: Text(
                    community.currentUserRole == CommunityRole.creator
                        ? 'Роль: создатель'
                        : 'Роль: участник',
                  ),
                ),
                Chip(label: Text('Код: ${community.invitationCode}')),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _CommunityActionButton(
                  label: 'Запросы',
                  onPressed: () =>
                      context.push('/communities/${community.id}/requests'),
                ),
                _CommunityActionButton(
                  label: 'Участники',
                  onPressed: () async {
                    if (ref.read(profileControllerProvider).profile == null) {
                      await ref.read(profileControllerProvider.notifier).load();
                    }
                    await ref
                        .read(communityControllerProvider.notifier)
                        .loadMembers(community.id);
                    if (!context.mounted) {
                      return;
                    }
                    final communityState = ref.read(
                      communityControllerProvider,
                    );
                    final members = _membersWithCurrentUser(
                      community: community,
                      loadedMembers:
                          communityState.membersByCommunity[community.id] ??
                          const [],
                      profile: ref.read(profileControllerProvider).profile,
                      fallbackUser: FirebaseAuth.instance.currentUser,
                    );
                    final loadError =
                        communityState.memberErrorsByCommunity[community.id];
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              'Участники',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            if (loadError != null) ...[
                              Text(
                                loadError,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (members.isEmpty)
                              const Text('Список участников пока недоступен')
                            else
                              ...members.map(
                                (member) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        member.profile.avatarUrl != null &&
                                            member.profile.avatarUrl!.isNotEmpty
                                        ? NetworkImage(
                                            member.profile.avatarUrl!,
                                          )
                                        : null,
                                    child:
                                        member.profile.avatarUrl == null ||
                                            member.profile.avatarUrl!.isEmpty
                                        ? Text(_memberInitial(member))
                                        : null,
                                  ),
                                  title: Text(
                                    member.profile.name.isEmpty
                                        ? 'Вы'
                                        : member.profile.name,
                                  ),
                                  subtitle: Text(
                                    member.role == CommunityRole.creator
                                        ? 'Создатель'
                                        : 'Участник',
                                  ),
                                  trailing:
                                      isCreator &&
                                          member.role != CommunityRole.creator
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: () => context.push(
                                                '/profile/reviews/${member.userId}',
                                              ),
                                              child: Text(
                                                _ratingText(
                                                  member.profile.rating,
                                                  member.profile.reviewsCount,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () async {
                                                final confirmed =
                                                    await _confirmCreatorTransfer(
                                                      context,
                                                      member.profile.name
                                                              .trim()
                                                              .isEmpty
                                                          ? 'участника'
                                                          : member.profile.name
                                                                .trim(),
                                                    );
                                                if (!confirmed) {
                                                  return;
                                                }
                                                final success = await ref
                                                    .read(
                                                      communityControllerProvider
                                                          .notifier,
                                                    )
                                                    .transferCreatorRole(
                                                      communityId: community.id,
                                                      newCreatorUserId:
                                                          member.userId,
                                                    );
                                                if (context.mounted &&
                                                    success) {
                                                  Navigator.of(context).pop();
                                                }
                                              },
                                              icon: const Icon(
                                                Icons
                                                    .workspace_premium_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () async {
                                                final confirmed =
                                                    await _confirmMemberRemoval(
                                                      context,
                                                      member.profile.name
                                                              .trim()
                                                              .isEmpty
                                                          ? 'участника'
                                                          : member.profile.name
                                                                .trim(),
                                                    );
                                                if (!confirmed) {
                                                  return;
                                                }
                                                final success = await ref
                                                    .read(
                                                      communityControllerProvider
                                                          .notifier,
                                                    )
                                                    .removeMember(
                                                      communityId: community.id,
                                                      memberUserId:
                                                          member.userId,
                                                    );
                                                if (context.mounted &&
                                                    success) {
                                                  Navigator.of(context).pop();
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.person_remove_outlined,
                                              ),
                                            ),
                                          ],
                                        )
                                      : TextButton(
                                          onPressed: () => context.push(
                                            '/profile/reviews/${member.userId}',
                                          ),
                                          child: Text(
                                            _ratingText(
                                              member.profile.rating,
                                              member.profile.reviewsCount,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
                if (isCreator)
                  _CommunityActionButton(
                    label: 'Изменить',
                    onPressed: () =>
                        _showEditCommunityDialog(context, ref, community),
                  ),
                if (!isCreator)
                  _CommunityActionButton(
                    label: 'Покинуть',
                    danger: true,
                    onPressed: () async {
                      final confirmed = await _confirmLeaveCommunity(context);
                      if (!confirmed) {
                        return;
                      }
                      final success = await ref
                          .read(communityControllerProvider.notifier)
                          .leaveCommunity(community.id);
                      if (!context.mounted) {
                        return;
                      }
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ref.read(communityControllerProvider).error ??
                                  'Не удалось покинуть сообщество',
                            ),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  const _CommunityActionButton({
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 144,
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return OutlinedButton(
      onPressed: onPressed,
      style: danger
          ? OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            )
          : null,
      child: child,
    );
  }
}

List<CommunityMember> _membersWithCurrentUser({
  required Community community,
  required List<CommunityMember> loadedMembers,
  required Profile? profile,
  required User? fallbackUser,
}) {
  final currentUserId = profile?.userId ?? fallbackUser?.uid;
  final safeProfile = profile != null && profile.userId == currentUserId
      ? profile
      : null;
  final currentProfile = safeProfile ?? _fallbackProfile(fallbackUser);
  if (currentProfile == null) {
    return loadedMembers;
  }
  if (loadedMembers.any((member) => member.userId == currentUserId)) {
    return loadedMembers.map((member) {
      if (member.userId != currentUserId) {
        return member;
      }
      return CommunityMember(
        communityId: member.communityId,
        userId: member.userId,
        role: member.role,
        joinedAt: member.joinedAt,
        profile: currentProfile,
      );
    }).toList();
  }
  return [
    CommunityMember(
      communityId: community.id,
      userId: currentProfile.userId,
      role: community.currentUserRole,
      joinedAt: community.createdAt,
      profile: currentProfile,
    ),
    ...loadedMembers,
  ];
}

Profile? _fallbackProfile(User? user) {
  if (user == null) {
    return null;
  }
  final displayName = user.displayName?.trim();
  return Profile(
    userId: user.uid,
    email: '',
    phone: '',
    name: displayName != null && displayName.isNotEmpty ? displayName : 'Вы',
    avatarUrl: user.photoURL,
    bio: '',
    rating: 0,
    completedServicesCount: 0,
    reviewsCount: 0,
    communityIds: const [],
    notificationSettings: NotificationSettings.defaults(),
  );
}

String _memberInitial(CommunityMember member) {
  final name = member.profile.name.trim();
  if (name.isEmpty) {
    return '?';
  }
  return name.substring(0, 1).toUpperCase();
}

Future<void> _showCreateCommunityDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _CreateCommunityDialog(ref: ref),
  );
}

Future<void> _showJoinCommunityDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _JoinCommunityDialog(ref: ref),
  );
}

Future<bool> _confirmLeaveCommunity(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Покинуть сообщество?'),
          content: const Text('Вы точно хотите покинуть сообщество?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Покинуть'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> _confirmMemberRemoval(
  BuildContext context,
  String memberName,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить участника?'),
          content: Text(
            'Удалить $memberName из сообщества? У пользователя пропадёт доступ к этому сообществу.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Удалить'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> _confirmCreatorTransfer(
  BuildContext context,
  String memberName,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Передать роль создателя?'),
          content: Text(
            'Передать роль создателя пользователю $memberName? После этого вы сможете покинуть сообщество как обычный участник.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Передать'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> _confirmDeleteCommunity(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить сообщество?'),
          content: const Text(
            'В случае удаления у всех пользователей пропадёт доступ к сообществу и его запросам. Это действие безвозвратно. Вы точно хотите удалить сообщество?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Удалить'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> _confirmRegenerateInvitationCode(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Сменить ссылку приглашения?'),
          content: const Text(
            'Старый код и старая ссылка перестанут подходить для вступления. Уже добавленные участники останутся в сообществе.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Сменить'),
            ),
          ],
        ),
      ) ??
      false;
}

class _JoinCommunityDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _JoinCommunityDialog({required this.ref});

  @override
  ConsumerState<_JoinCommunityDialog> createState() =>
      _JoinCommunityDialogState();
}

class _JoinCommunityDialogState extends ConsumerState<_JoinCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _linkController = TextEditingController();
  bool _useLink = false;

  @override
  void dispose() {
    _codeController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = (_useLink ? _linkController : _codeController).text.trim();
    if (!_useLink && !_formKey.currentState!.validate()) {
      return;
    }
    if (_useLink && value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ссылку приглашения')),
      );
      return;
    }

    final success = _useLink
        ? await widget.ref
              .read(communityControllerProvider.notifier)
              .joinCommunityByLink(value)
        : await widget.ref
              .read(communityControllerProvider.notifier)
              .joinCommunityByCode(value.toUpperCase());

    if (!mounted) {
      return;
    }

    if (success) {
      context.pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.ref.read(communityControllerProvider).error ??
              'Не удалось присоединиться',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Вступить в сообщество'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('По коду'),
                    icon: Icon(Icons.password_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('По ссылке'),
                    icon: Icon(Icons.link_outlined),
                  ),
                ],
                selected: {_useLink},
                onSelectionChanged: (selection) {
                  setState(() {
                    _useLink = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_useLink)
                TextField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: 'Ссылка приглашения',
                  ),
                )
              else
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Код приглашения',
                  ),
                  validator: Validators.invitationCode,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_useLink ? 'Открыть по ссылке' : 'Вступить по коду'),
        ),
      ],
    );
  }
}

Future<void> _showEditCommunityDialog(
  BuildContext context,
  WidgetRef ref,
  Community community,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _EditCommunityDialog(ref: ref, community: community),
  );
}

class _CreateCommunityDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _CreateCommunityDialog({required this.ref});

  @override
  ConsumerState<_CreateCommunityDialog> createState() =>
      _CreateCommunityDialogState();
}

class _CreateCommunityDialogState
    extends ConsumerState<_CreateCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _imageUrl;
  File? _selectedImageFile;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImageUploadService().pickImageFromGallery();
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedImageFile = File(picked.path);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    String? imageUrl = _imageUrl;
    if (_selectedImageFile != null) {
      setState(() {
        _uploadingImage = true;
      });
      try {
        imageUrl = await ImageUploadService().uploadImage(
          file: XFile(_selectedImageFile!.path),
          folder: 'community_images',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mapAppError(e))));
          setState(() {
            _uploadingImage = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _imageUrl = imageUrl;
        });
      }
    }
    final success = await widget.ref
        .read(communityControllerProvider.notifier)
        .createCommunity(
          name: _nameController.text,
          description: _descriptionController.text,
          imageUrl: imageUrl,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _selectedImageFile != null
        ? FileImage(_selectedImageFile!)
        : (_imageUrl != null && _imageUrl!.isNotEmpty
              ? NetworkImage(_imageUrl!)
              : null);

    return AlertDialog(
      title: const Text('Создать сообщество'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage: imageProvider as ImageProvider<Object>?,
                child: imageProvider == null
                    ? const Icon(Icons.groups_outlined)
                    : null,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploadingImage ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Выбрать изображение'),
                  ),
                  if (_selectedImageFile != null ||
                      (_imageUrl != null && _imageUrl!.isNotEmpty))
                    TextButton(
                      onPressed: _uploadingImage
                          ? null
                          : () {
                              setState(() {
                                _selectedImageFile = null;
                                _imageUrl = null;
                              });
                            },
                      child: const Text('Убрать'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: Validators.communityName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание'),
                validator: Validators.communityDescription,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _uploadingImage ? null : _submit,
          child: const Text('Создать'),
        ),
      ],
    );
  }
}

class _EditCommunityDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final Community community;

  const _EditCommunityDialog({required this.ref, required this.community});

  @override
  ConsumerState<_EditCommunityDialog> createState() =>
      _EditCommunityDialogState();
}

class _EditCommunityDialogState extends ConsumerState<_EditCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _imageUrl;
  File? _selectedImageFile;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.community.name);
    _descriptionController = TextEditingController(
      text: widget.community.description,
    );
    _imageUrl = widget.community.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImageUploadService().pickImageFromGallery();
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedImageFile = File(picked.path);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    String? imageUrl = _imageUrl;
    if (_selectedImageFile != null) {
      setState(() {
        _uploadingImage = true;
      });
      try {
        imageUrl = await ImageUploadService().uploadImage(
          file: XFile(_selectedImageFile!.path),
          folder: 'community_images',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mapAppError(e))));
          setState(() {
            _uploadingImage = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _imageUrl = imageUrl;
        });
      }
    }
    final success = await widget.ref
        .read(communityControllerProvider.notifier)
        .updateCommunity(
          communityId: widget.community.id,
          name: _nameController.text,
          description: _descriptionController.text,
          imageUrl: imageUrl,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      context.pop();
    }
  }

  Future<void> _regenerateInvitationCode() async {
    final confirmed = await _confirmRegenerateInvitationCode(context);
    if (!confirmed || !mounted) {
      return;
    }
    final success = await widget.ref
        .read(communityControllerProvider.notifier)
        .regenerateInvitationCode(widget.community.id);
    if (!mounted) {
      return;
    }
    if (success) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка приглашения обновлена')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.ref.read(communityControllerProvider).error ??
              'Не удалось сменить ссылку',
        ),
      ),
    );
  }

  Future<void> _copyInvitationLink() async {
    await Clipboard.setData(
      ClipboardData(text: widget.community.invitationLink),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  Future<void> _deleteCommunity() async {
    final confirmed = await _confirmDeleteCommunity(context);
    if (!confirmed || !mounted) {
      return;
    }
    final success = await widget.ref
        .read(communityControllerProvider.notifier)
        .deleteCommunity(widget.community.id);
    if (!mounted) {
      return;
    }
    if (success) {
      context.pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.ref.read(communityControllerProvider).error ??
              'Не удалось удалить сообщество',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _selectedImageFile != null
        ? FileImage(_selectedImageFile!)
        : (_imageUrl != null && _imageUrl!.isNotEmpty
              ? NetworkImage(_imageUrl!)
              : null);

    return AlertDialog(
      title: const Text('Изменить сообщество'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage: imageProvider as ImageProvider<Object>?,
                child: imageProvider == null
                    ? const Icon(Icons.groups_outlined)
                    : null,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploadingImage ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Выбрать изображение'),
                  ),
                  if (_selectedImageFile != null ||
                      (_imageUrl != null && _imageUrl!.isNotEmpty))
                    TextButton(
                      onPressed: _uploadingImage
                          ? null
                          : () {
                              setState(() {
                                _selectedImageFile = null;
                                _imageUrl = null;
                              });
                            },
                      child: const Text('Убрать'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: Validators.communityName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание'),
                validator: Validators.communityDescription,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.password_outlined),
                title: const Text('Код приглашения'),
                subtitle: Text(widget.community.invitationCode),
                trailing: TextButton(
                  onPressed: _uploadingImage ? null : _regenerateInvitationCode,
                  child: const Text('Сменить'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_outlined),
                title: const Text('Ссылка приглашения'),
                subtitle: Text(
                  widget.community.invitationLink,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _copyInvitationLink,
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Скопировать ссылку'),
                  ),
                  TextButton.icon(
                    onPressed: _uploadingImage
                        ? null
                        : _regenerateInvitationCode,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Сменить ссылку'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _uploadingImage ? null : _deleteCommunity,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить сообщество'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _uploadingImage ? null : _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

String _ratingText(double rating, int reviewsCount) {
  if (reviewsCount == 0) {
    return 'Нет рейтинга · 0 отзывов';
  }
  return '${rating.toStringAsFixed(1)} · отзывов: $reviewsCount';
}
