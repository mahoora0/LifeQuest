import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _initialize(UserProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _nicknameController.text = profile.nickname;
    _imageUrlController.text = profile.profileImageUrl ?? '';
    _imageUrlController.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateProfile(
            nickname: _nicknameController.text.trim(),
            profileImageUrl: _imageUrlController.text.trim(),
          );
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
    return Scaffold(
      backgroundColor: LqColors.surface,
      appBar: AppBar(
        backgroundColor: LqColors.surface,
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
            final imageUrl = _imageUrlController.text.trim();
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                LqSpacing.screen,
                16,
                LqSpacing.screen,
                32,
              ),
              children: [
                Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LqColors.card,
                      border: Border.all(
                        color: LqColors.ink,
                        width: LqShape.borderWidth,
                      ),
                      boxShadow: LqShape.cardShadow,
                    ),
                    child: imageUrl.isEmpty
                        ? const LqImage(
                            LqAssets.charFront,
                            width: 104,
                            fallbackShape: LqImageFallbackShape.circle,
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const LqImage(
                              LqAssets.charFront,
                              width: 104,
                              fallbackShape: LqImageFallbackShape.circle,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 22),
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
                          textInputAction: TextInputAction.next,
                          validator: (text) {
                            final value = text?.trim() ?? '';
                            if (value.length < 2 || value.length > 20) {
                              return '닉네임은 2~20자로 입력해 주세요.';
                            }
                            if (!RegExp(
                              r'^[가-힣a-zA-Z0-9_]+$',
                            ).hasMatch(value)) {
                              return '한글, 영문, 숫자, 밑줄만 사용할 수 있어요.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _imageUrlController,
                          label: '프로필 이미지 URL',
                          hint: '비워 두면 기본 캐릭터가 보여요',
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          validator: (text) {
                            final value = text?.trim() ?? '';
                            if (value.isEmpty) return null;
                            final uri = Uri.tryParse(value);
                            if (uri == null ||
                                !uri.hasScheme ||
                                !{'http', 'https'}.contains(uri.scheme)) {
                              return 'http 또는 https 이미지 주소를 입력해 주세요.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _save(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '이미지 업로드 저장소는 아직 없어 URL 방식으로 연결해요.',
                            style: LqText.caption,
                          ),
                        ),
                        const SizedBox(height: 22),
                        LqButton(
                          label: '변경 내용 저장',
                          busy: _busy,
                          onPressed: _save,
                        ),
                      ],
                    ),
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
