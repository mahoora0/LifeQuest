import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/core/config/app_config.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_progress_bar.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 무효화만 하면 동기적으로 끝나 스피너가 즉시 사라진다.
/// 실제 재조회가 끝날 때까지 기다려야 당김-새로고침이 의미를 갖는다.
Future<void> _refresh(WidgetRef ref) async {
  ref
    ..invalidate(myProfileProvider)
    ..invalidate(levelStatusProvider)
    ..invalidate(rewardHistoryProvider)
    ..invalidate(badgeCollectionProvider)
    ..invalidate(questHistoryProvider);

  await Future.wait([
    _settle(ref.read(myProfileProvider.future)),
    _settle(ref.read(levelStatusProvider.future)),
    _settle(ref.read(rewardHistoryProvider.future)),
    _settle(ref.read(badgeCollectionProvider.future)),
    _settle(ref.read(questHistoryProvider.future)),
  ]);
}

/// 개별 조회 실패는 각 위젯이 오류 상태로 보여주므로
/// 여기서는 삼켜서 새로고침 제스처 자체가 깨지지 않게 한다.
Future<void> _settle(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {
    // 무시 — 화면이 오류 상태를 렌더링한다.
  }
}

/// S-03·S-05·S-06 마이페이지.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: LqAsyncView<UserProfile>(
          value: profile,
          onRetry: () => ref.invalidate(myProfileProvider),
          data: (value) => RefreshIndicator(
            color: LqColors.primary,
            backgroundColor: LqColors.surfaceRaised,
            onRefresh: () => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                LqSpacing.screen,
                12,
                LqSpacing.screen,
                24,
              ),
              children: [
                _ProfileHeader(profile: value),
                const SizedBox(height: LqSpacing.gap),
                _CharacterCard(character: value.selectedCharacter),
                const SizedBox(height: LqSpacing.gap),
                const _ExpCard(),
                // ① 재화 2칸은 서버에 재화가 없어 v1에서 노출하지 않는다.
                const SizedBox(height: LqSpacing.gap),
                const _GrowthRecordCard(),
                const SizedBox(height: LqSpacing.gap),
                const _BadgeCard(),
                const SizedBox(height: LqSpacing.gap),
                const _RewardHistoryCard(),
                const SizedBox(height: LqSpacing.gap),
                _MenuCard(representativeTitle: value.representativeTitle),
                const SizedBox(height: LqSpacing.gap),
                const _LogoutRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardHistoryCard extends ConsumerWidget {
  const _RewardHistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardHistoryProvider);
    final entries = <String>[
      if (rewards.hasValue)
        ...rewards.requireValue.titles.map((item) => '칭호 · ${item.name}'),
      if (rewards.hasValue)
        ...rewards.requireValue.profileItems.map(
          (item) => '${item.itemType == 'BADGE' ? '배지' : '아이템'} · ${item.name}',
        ),
    ];

    return LqCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('획득 보상', style: LqText.cardTitle),
          const SizedBox(height: 8),
          if (rewards.isLoading)
            const LinearProgressIndicator(minHeight: 3)
          else if (rewards.hasError)
            Text('보상 이력을 불러오지 못했어요.', style: LqText.caption)
          else if (entries.isEmpty)
            Text('아직 획득한 보상이 없어요.', style: LqText.caption)
          else
            for (final entry in entries.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      size: 17,
                      color: LqColors.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(entry, style: LqText.bodySm)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(levelStatusProvider);
    final imageUrl = AppConfig.resolveMediaUrl(profile.profileImageUrl);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 74,
          height: 74,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: LqColors.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
          ),
          child: imageUrl.isEmpty
              ? const Icon(
                  Icons.person_outline_rounded,
                  size: 42,
                  color: LqColors.textMuted,
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person_outline_rounded,
                    size: 42,
                    color: LqColors.textMuted,
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      profile.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LqText.sectionTitle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/profile/edit'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: LqColors.surfaceRaised,
                        borderRadius: LqShape.pillRadius,
                        border: Border.all(
                          color: LqColors.borderMuted,
                          width: 1.6,
                        ),
                      ),
                      child: Text(
                        '변경',
                        style: LqText.badge.copyWith(
                          fontSize: 12,
                          color: LqColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                profile.representativeTitle ?? '대표 칭호 없음',
                style: LqText.bodySm.copyWith(
                  fontSize: 14.5,
                  color: profile.representativeTitle == null
                      ? LqColors.textMuted
                      : LqColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                level.value == null
                    ? 'Lv. —'
                    : 'Lv. ${level.requireValue.level}',
                style: LqText.levelNumber,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character});

  final AvatarCharacter? character;

  @override
  Widget build(BuildContext context) {
    final selected = character;
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 92,
            child: selected == null
                ? const Icon(
                    Icons.smart_toy_outlined,
                    size: 46,
                    color: LqColors.textMuted,
                  )
                : Image.asset(
                    LqAssets.character(selected.code),
                    fit: BoxFit.contain,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('내 캐릭터', style: LqText.caption),
                const SizedBox(height: 2),
                Text(selected?.name ?? '선택 안 함', style: LqText.sectionTitle),
                const SizedBox(height: 4),
                Text('프로필 수정에서 캐릭터를 바꿀 수 있어요.', style: LqText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpCard extends ConsumerWidget {
  const _ExpCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(levelStatusProvider);
    final status = level.value;

    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                status == null
                    ? 'EXP —'
                    : 'EXP ${status.currentLevelExp} / ${status.nextLevelRequiredExp}',
                style: LqText.bodySm.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                status == null ? '' : '다음 레벨까지 ${status.remainingExp}',
                style: LqText.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LqProgressBar(
            value: status?.currentLevelExp ?? 0,
            max: status?.nextLevelRequiredExp ?? 0,
          ),
        ],
      ),
    );
  }
}

class _GrowthRecordCard extends ConsumerWidget {
  const _GrowthRecordCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(questHistoryProvider);
    final level = ref.watch(levelStatusProvider);

    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('성장 기록', style: LqText.cardTitle),
          const SizedBox(height: 10),
          Row(
            children: [
              _RecordCell(
                label: '퀘스트 완료',
                value: history.value == null
                    ? '—'
                    : '${history.requireValue.totalElements}',
              ),
              // ② 연속 달성은 서버 판정이 필요해 v1에서 노출하지 않는다.
              if (LqFeatures.streakEnabled)
                const _RecordCell(label: '연속 달성', value: '—'),
              _RecordCell(
                label: '총 EXP',
                value: level.value == null
                    ? '—'
                    : '${level.requireValue.totalExp}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordCell extends StatelessWidget {
  const _RecordCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: LqText.levelNumber.copyWith(fontSize: 21)),
          const SizedBox(height: 2),
          Text(label, style: LqText.caption),
        ],
      ),
    );
  }
}

class _BadgeCard extends ConsumerWidget {
  const _BadgeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(badgeCollectionProvider);
    final items = collection.value?.badges ?? const <ProfileItem>[];
    final selectedId = collection.value?.representativeBadgeId;

    return LqCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('내 배지', style: LqText.cardTitle),
              const Spacer(),
              Text('탭해서 대표 설정', style: LqText.caption),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _BadgeSlot(
                    item: i < items.length ? items[i] : null,
                    selected: i < items.length && items[i].id == selectedId,
                    onTap: i < items.length && items[i].id != null
                        ? () => _selectBadge(context, ref, items[i].id!)
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectBadge(
    BuildContext context,
    WidgetRef ref,
    int badgeId,
  ) async {
    try {
      await ref.read(badgeCollectionProvider.notifier).select(badgeId);
    } catch (error) {
      if (context.mounted) showLqError(context, error);
    }
  }
}

class _BadgeSlot extends StatelessWidget {
  const _BadgeSlot({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ProfileItem? item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final empty = item == null;

    return LqCard(
      radius: LqShape.tileRadius,
      locked: empty,
      // 배지 슬롯은 카드가 아니라 타일이라 레이어링 규칙의 주 카드 토큰을 쓰지 않는다.
      background: LqColors.surfaceTint,
      onTap: onTap,
      shadow: false,
      height: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            empty ? '?' : item!.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: LqText.caption.copyWith(
              fontSize: 12,
              fontWeight: empty ? FontWeight.w400 : FontWeight.w700,
              color: empty ? LqColors.textMuted : LqColors.textPrimary,
            ),
          ),
          if (selected)
            const Align(
              alignment: Alignment.topRight,
              child: Icon(
                Icons.check_circle,
                size: 16,
                color: LqColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.representativeTitle});

  final String? representativeTitle;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          _MenuRow(label: '프로필 수정', onTap: () => context.push('/profile/edit')),
          const LqDashedDivider(),
          _MenuRow(
            label: '칭호 선택',
            trailing: representativeTitle ?? '없음',
            onTap: () => context.push('/achievements?tab=titles'),
          ),
          const LqDashedDivider(),
          _MenuRow(
            label: '알림 설정',
            onTap: () => context.push('/settings/notifications'),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap, this.trailing});

  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: LqSpacing.minTouchTarget,
        child: Row(
          children: [
            Text(label, style: LqText.bodySm),
            const Spacer(),
            if (trailing != null) Text(trailing!, style: LqText.caption),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: LqColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutRow extends ConsumerStatefulWidget {
  const _LogoutRow();

  @override
  ConsumerState<_LogoutRow> createState() => _LogoutRowState();
}

class _LogoutRowState extends ConsumerState<_LogoutRow> {
  bool _busy = false;

  Future<void> _logout() async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: LqColors.ink.withValues(alpha: 0.45),
      builder: (dialogContext) => _LogoutDialog(
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).logout();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showLqError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : _logout,
          child: SizedBox(
            height: LqSpacing.minTouchTarget,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _busy
                    ? Row(
                        key: const ValueKey('logout-busy'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: LqColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '로그아웃 중…',
                            style: LqText.bodySm.copyWith(
                              color: LqColors.textMuted,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '로그아웃',
                        key: const ValueKey('logout-idle'),
                        style: LqText.bodySm.copyWith(
                          color: LqColors.textMuted,
                        ),
                      ),
              ),
            ),
          ),
        ),
        Text('v${AppConfig.appVersion}', style: LqText.caption),
      ],
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: LqCard(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: LqColors.warnBg,
                borderRadius: LqShape.tileRadius,
                border: LqShape.inkBorder,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: LqColors.accent,
                size: 27,
              ),
            ),
            const SizedBox(height: 14),
            Text('로그아웃할까요?', style: LqText.sectionTitle),
            const SizedBox(height: 8),
            Text(
              '현재 기기에서만 로그아웃돼요.\n퀘스트와 성장 기록은 그대로 보관됩니다.',
              textAlign: TextAlign.center,
              style: LqText.bodySm,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LqButton(
                    label: '취소',
                    height: 46,
                    background: LqColors.surfaceRaised,
                    foreground: LqColors.textPrimary,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LqButton(
                    label: '로그아웃',
                    height: 46,
                    background: LqColors.accent,
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
