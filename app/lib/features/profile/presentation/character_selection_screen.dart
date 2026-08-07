import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
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
  final Map<int, int?> _accessoryOverrides = {};
  bool _accessoryBusy = false;
  int? _pendingAccessoryId;

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

  Future<void> _selectAccessory(
    AvatarAccessory? accessory,
    int characterId,
  ) async {
    final nextId = accessory?.id;
    if (_accessoryBusy ||
        (_accessoryOverrides.containsKey(characterId) &&
            _accessoryOverrides[characterId] == nextId)) {
      return;
    }
    setState(() {
      _accessoryBusy = true;
      _pendingAccessoryId = nextId;
    });
    try {
      final updated = await ref
          .read(userRepositoryProvider)
          .selectAccessory(nextId);
      if (!mounted) return;
      setState(() {
        _accessoryOverrides[characterId] = updated.selectedAccessory?.id;
        _accessoryBusy = false;
        _pendingAccessoryId = null;
      });
      ref.invalidate(myProfileProvider);
      ref.invalidate(accessoryCollectionProvider);
      showLqSnack(
        context,
        accessory == null ? '액세서리를 해제했어요.' : '${accessory.name}을(를) 착용했어요.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _accessoryBusy = false;
        _pendingAccessoryId = null;
      });
      showLqError(context, error);
    }
  }

  Future<void> _previewAccessory(
    AvatarAccessory accessory,
    AvatarCharacter character,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: LqColors.ink.withValues(alpha: 0.45),
      builder: (dialogContext) => _AccessoryPreviewDialog(
        accessory: accessory,
        character: character,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed == true && mounted) {
      await _selectAccessory(accessory, character.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final characters = ref.watch(characterCollectionProvider);
    final accessories = ref.watch(accessoryCollectionProvider);
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
          data: (characterItems) => LqAsyncView<AccessoryCollection>(
            value: accessories,
            onRetry: () => ref.invalidate(accessoryCollectionProvider),
            data: (collection) {
              final equippedByCharacter = <int, int?>{
                ...collection.selectedAccessoryIdsByCharacter,
                ..._accessoryOverrides,
              };
              if (selectedId != null &&
                  !equippedByCharacter.containsKey(selectedId) &&
                  collection.selectedAccessoryId != null) {
                equippedByCharacter[selectedId] =
                    collection.selectedAccessoryId;
              }
              final selectedAccessoryId = selectedId == null
                  ? null
                  : equippedByCharacter[selectedId];
              final selectedCharacter = characterItems
                  .where((item) => item.id == selectedId)
                  .firstOrNull;
              return CustomScrollView(
                slivers: [
                  const _SectionHeader(title: '캐릭터'),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      LqSpacing.screen,
                      0,
                      LqSpacing.screen,
                      18,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: characterItems.length,
                      itemBuilder: (context, index) {
                        final character = characterItems[index];
                        final accessoryId = equippedByCharacter[character.id];
                        final characterAccessory = collection.accessories
                            .where((item) => item.id == accessoryId)
                            .firstOrNull;
                        return _CharacterChoice(
                          character: character,
                          accessoryCode: characterAccessory?.code,
                          selected: character.id == selectedId,
                          busy: character.id == _busyId,
                          onTap: character.unlocked
                              ? () => _select(character)
                              : null,
                        );
                      },
                    ),
                  ),
                  const _SectionHeader(
                    title: '액세서리',
                    hint: '레벨이 오를 때마다 새로운 액세서리가 열려요.',
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      LqSpacing.screen,
                      0,
                      LqSpacing.screen,
                      32,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: collection.accessories.length + 1,
                      itemBuilder: (context, index) {
                        final accessory = index == 0
                            ? null
                            : collection.accessories[index - 1];
                        final unlocked = accessory?.unlocked ?? true;
                        final accessoryId = accessory?.id;
                        return _AccessoryChoice(
                          accessory: accessory,
                          selected: accessoryId == selectedAccessoryId,
                          busy:
                              _accessoryBusy &&
                              _pendingAccessoryId == accessoryId,
                          onTap: unlocked
                              ? selectedCharacter == null
                                    ? null
                                    : accessory == null
                                    ? () => _selectAccessory(
                                        null,
                                        selectedCharacter.id,
                                      )
                                    : () => _previewAccessory(
                                        accessory,
                                        selectedCharacter,
                                      )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
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
    this.accessoryCode,
    required this.selected,
    required this.busy,
    this.onTap,
  });

  final AvatarCharacter character;
  final String? accessoryCode;
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
                        LqAssets.characterWithAccessory(
                          character.code,
                          accessoryCode,
                        ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LqSpacing.screen,
          14,
          LqSpacing.screen,
          10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: LqText.sectionTitle),
            if (hint != null) ...[
              const SizedBox(height: 3),
              Text(hint!, style: LqText.caption),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccessoryChoice extends StatelessWidget {
  const _AccessoryChoice({
    required this.accessory,
    required this.selected,
    required this.busy,
    this.onTap,
  });

  final AvatarAccessory? accessory;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = accessory?.unlocked ?? true;
    return LqCard(
      key: ValueKey('accessory-card-${accessory?.id ?? 'none'}'),
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
                    child: accessory == null
                        ? const Icon(
                            Icons.block_rounded,
                            size: 42,
                            color: LqColors.textMuted,
                          )
                        : Opacity(
                            opacity: unlocked ? 1 : 0.42,
                            child: LqImage(
                              LqAssets.accessory(accessory!.code),
                              width: 64,
                              height: 64,
                            ),
                          ),
                  ),
                ),
                Text(
                  accessory?.name ?? '착용 안 함',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LqText.cardTitle.copyWith(fontSize: 13),
                ),
                if (!unlocked)
                  Text(
                    accessory!.requiredLevel == null
                        ? '보상 설정 예정'
                        : 'Lv. ${accessory!.requiredLevel} 해금',
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
          if (!unlocked)
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

class _AccessoryPreviewDialog extends StatelessWidget {
  const _AccessoryPreviewDialog({
    required this.accessory,
    required this.character,
    required this.onCancel,
    required this.onConfirm,
  });

  final AvatarAccessory accessory;
  final AvatarCharacter character;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: LqCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(accessory.name, style: LqText.sectionTitle),
            const SizedBox(height: 8),
            Container(
              width: 220,
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LqColors.surfaceTint,
                borderRadius: LqShape.tileRadius,
                border: Border.all(color: LqColors.borderMuted, width: 1.6),
              ),
              child: LqImage(
                LqAssets.characterWithAccessory(character.code, accessory.code),
                width: 204,
                height: 204,
              ),
            ),
            const SizedBox(height: 8),
            Text('${character.name} 착용 미리보기', style: LqText.caption),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LqButton(
                    label: '취소',
                    height: 46,
                    background: LqColors.surfaceRaised,
                    foreground: LqColors.textPrimary,
                    shadow: false,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LqButton(
                    label: '착용하기',
                    height: 46,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
