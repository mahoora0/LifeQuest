import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_quest/core/config/app_config.dart';
import 'package:life_quest/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  bool _initialized = false;
  bool _busy = false;
  int? _selectingCharacterId;
  String? _profileImageUrl;
  int? _selectedCharacterId;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _initialize(UserProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _nicknameController.text = profile.nickname;
    _profileImageUrl = profile.profileImageUrl;
    _selectedCharacterId = profile.selectedCharacter?.id;
  }

  Future<void> _pickProfileImage() async {
    if (_busy) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(userRepositoryProvider)
          .uploadProfileImage(picked.path);
      setState(() => _profileImageUrl = updated.profileImageUrl);
      ref.invalidate(myProfileProvider);
      if (mounted) showLqSnack(context, '프로필 사진을 변경했어요.');
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProfileImage() async {
    if (_busy || _profileImageUrl == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(userRepositoryProvider).deleteProfileImage();
      setState(() => _profileImageUrl = null);
      ref.invalidate(myProfileProvider);
      if (mounted) showLqSnack(context, '기본 프로필로 돌아왔어요.');
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectCharacter(AvatarCharacter character) async {
    if (_selectingCharacterId != null || character.id == _selectedCharacterId) {
      return;
    }
    setState(() => _selectingCharacterId = character.id);
    try {
      await ref.read(userRepositoryProvider).selectCharacter(character.id);
      setState(() => _selectedCharacterId = character.id);
      ref.invalidate(myProfileProvider);
      if (mounted) showLqSnack(context, '${character.name}(으)로 변경했어요.');
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => _selectingCharacterId = null);
    }
  }

  Future<void> _saveNickname() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateProfile(nickname: _nicknameController.text.trim());
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      showLqSnack(context, '프로필을 저장했어요.');
      context.pop();
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final characters = ref.watch(characterCollectionProvider);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      appBar: AppBar(
        backgroundColor: LqColors.surfacePanel,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: LqColors.ink),
        ),
        title: const Text('프로필 수정', style: LqText.screenTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LqAsyncView<UserProfile>(
          value: profile,
          onRetry: () => ref.invalidate(myProfileProvider),
          data: (value) {
            _initialize(value);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                LqSpacing.screen,
                16,
                LqSpacing.screen,
                32,
              ),
              children: [
                _ProfilePhoto(
                  imageUrl: _profileImageUrl,
                  busy: _busy,
                  onPick: _pickProfileImage,
                  onDelete: _profileImageUrl == null
                      ? null
                      : _deleteProfileImage,
                ),
                const SizedBox(height: LqSpacing.gap),
                LqCard(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AuthTextField(
                          controller: _nicknameController,
                          label: '닉네임',
                          hint: '2~20자, 한글·영문·숫자',
                          textInputAction: TextInputAction.done,
                          validator: (text) {
                            final nickname = text?.trim() ?? '';
                            if (nickname.length < 2 || nickname.length > 20) {
                              return '닉네임은 2~20자로 입력해 주세요.';
                            }
                            if (!RegExp(
                              r'^[가-힣a-zA-Z0-9_]+$',
                            ).hasMatch(nickname)) {
                              return '한글, 영문, 숫자, 밑줄만 사용할 수 있어요.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _saveNickname(),
                        ),
                        const SizedBox(height: 18),
                        LqButton(
                          label: '닉네임 저장',
                          busy: _busy,
                          onPressed: _saveNickname,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LqSpacing.gap),
                Text('내 캐릭터', style: LqText.sectionTitle),
                const SizedBox(height: 4),
                Text('프로필 사진과 별도로 사용할 게임 캐릭터예요.', style: LqText.caption),
                const SizedBox(height: 10),
                characters.when(
                  data: (items) => GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.88,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final character = items[index];
                      return _CharacterChoice(
                        character: character,
                        selected: character.id == _selectedCharacterId,
                        busy: character.id == _selectingCharacterId,
                        onTap: () => _selectCharacter(character),
                      );
                    },
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => LqCard(
                    child: Text('캐릭터 목록을 불러오지 못했어요.', style: LqText.caption),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({
    required this.imageUrl,
    required this.busy,
    required this.onPick,
    required this.onDelete,
  });

  final String? imageUrl;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.resolveMediaUrl(imageUrl);
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LqColors.surfaceRaised,
            border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
            boxShadow: LqShape.cardShadow,
          ),
          child: resolved.isEmpty
              ? const Icon(
                  Icons.person_outline_rounded,
                  size: 54,
                  color: LqColors.textMuted,
                )
              : Image.network(
                  resolved,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person_outline_rounded,
                    size: 54,
                    color: LqColors.textMuted,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: busy ? null : onPick,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(imageUrl == null ? '사진 선택' : '사진 변경'),
            ),
            if (onDelete != null)
              TextButton(
                onPressed: busy ? null : onDelete,
                child: const Text('삭제'),
              ),
          ],
        ),
        Text('JPG, PNG, WebP · 최대 5MB', style: LqText.caption),
      ],
    );
  }
}

class _CharacterChoice extends StatelessWidget {
  const _CharacterChoice({
    required this.character,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final AvatarCharacter character;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      onTap: onTap,
      background: selected ? LqColors.surfaceTint : LqColors.surfaceRaised,
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Image.asset(
                  LqAssets.character(character.code),
                  fit: BoxFit.contain,
                ),
              ),
              Text(character.name, style: LqText.cardTitle),
            ],
          ),
          if (selected)
            const Align(
              alignment: Alignment.topRight,
              child: Icon(Icons.check_circle, color: LqColors.primary),
            ),
          if (busy)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
