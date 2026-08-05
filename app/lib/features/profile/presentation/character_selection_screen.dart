import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class CharacterSelectionScreen extends ConsumerStatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  ConsumerState<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState
    extends ConsumerState<CharacterSelectionScreen> {
  int? _selectedId;
  int? _busyId;

  Future<void> _select(AvatarCharacter character) async {
    if (_busyId != null || _selectedId == character.id) return;
    setState(() => _busyId = character.id);
    try {
      final updated = await ref
          .read(userRepositoryProvider)
          .selectCharacter(character.id);
      if (!mounted) return;
      setState(() {
        _selectedId = updated.selectedCharacter?.id ?? character.id;
        _busyId = null;
      });
      ref.invalidate(myProfileProvider);
      showLqSnack(context, '${character.name}(으)로 변경했어요.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showLqError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final characters = ref.watch(characterCollectionProvider);
    final selectedId = _selectedId ?? profile.value?.selectedCharacter?.id;

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      appBar: AppBar(
        backgroundColor: LqColors.surfacePanel,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: LqColors.ink),
        ),
        title: const Text('캐릭터 꾸미기', style: LqText.screenTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LqAsyncView<List<AvatarCharacter>>(
          value: characters,
          onRetry: () => ref.invalidate(characterCollectionProvider),
          data: (items) => GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              LqSpacing.screen,
              16,
              LqSpacing.screen,
              32,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final character = items[index];
              return _CharacterChoice(
                character: character,
                selected: character.id == selectedId,
                busy: character.id == _busyId,
                onTap: character.unlocked ? () => _select(character) : null,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CharacterChoice extends StatelessWidget {
  const _CharacterChoice({
    required this.character,
    required this.selected,
    required this.busy,
    this.onTap,
  });

  final AvatarCharacter character;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      key: ValueKey('character-card-${character.id}'),
      onTap: onTap,
      background: selected ? LqColors.surfaceTint : LqColors.surfaceRaised,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    key: ValueKey('character-image-${character.id}'),
                    // Android GPU에서 비분리 블렌드 모드(특히 saturation)가
                    // GridView의 합성 경계를 본문 전체로 잘못 확장하는 경우가 있다.
                    // 잠금 상태는 투명도, 자물쇠, 해금 레벨만으로 표현해 화면 전체가
                    // 회색 레이어로 덮이는 현상을 피한다.
                    child: Opacity(
                      opacity: character.unlocked ? 1 : 0.45,
                      child: LqImage(
                        LqAssets.character(character.code),
                        width: 104,
                        height: 104,
                      ),
                    ),
                  ),
                ),
                Text(
                  character.name,
                  textAlign: TextAlign.center,
                  style: LqText.cardTitle,
                ),
                if (!character.unlocked)
                  Text(
                    'Lv. ${character.requiredLevel} 해금',
                    textAlign: TextAlign.center,
                    style: LqText.caption,
                  ),
              ],
            ),
          ),
          if (selected)
            const Align(
              alignment: Alignment.topRight,
              child: Icon(Icons.check_circle, color: LqColors.primary),
            ),
          if (!character.unlocked)
            const Align(
              alignment: Alignment.topRight,
              child: Icon(Icons.lock_rounded, color: LqColors.textMuted),
            ),
          if (busy)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
