import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/core/config/app_config.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_progress_bar.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 무효화만 하면 동기적으로 끝나 스피너가 즉시 사라진다.
/// 실제 재조회가 끝날 때까지 기다려야 당김-새로고침이 의미를 갖는다.
Future<void> _refresh(WidgetRef ref) async {
  ref
    ..invalidate(myProfileProvider)
    ..invalidate(levelStatusProvider)
    ..invalidate(rewardHistoryProvider)
    ..invalidate(questHistoryProvider)
    ..invalidate(lifedexOverviewProvider)
    ..invalidate(achievementOverviewProvider)
    ..invalidate(titleCollectionProvider);

  await Future.wait([
    _settle(ref.read(myProfileProvider.future)),
    _settle(ref.read(levelStatusProvider.future)),
    _settle(ref.read(rewardHistoryProvider.future)),
    _settle(ref.read(questHistoryProvider.future)),
    _settle(ref.read(lifedexOverviewProvider.future)),
    _settle(ref.read(achievementOverviewProvider.future)),
    _settle(ref.read(titleCollectionProvider.future)),
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
                const _MyRecordCard(),
                const SizedBox(height: LqSpacing.gap),
                const _RewardHistoryCard(),
                const SizedBox(height: LqSpacing.gap),
                const _MenuCard(),
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

/// "나의 기록" — 하단 탭에서 빠진 LifeDex 도감과 업적·칭호의 진입점.
///
/// 두 화면 모두 탭 밖 push 라우트가 되어 다른 경로로는 닿을 수 없다.
/// 각 행이 현재 진척을 함께 보여줘 열어 보지 않고도 상태를 알 수 있게 한다.
class _MyRecordCard extends ConsumerWidget {
  const _MyRecordCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifedex = ref.watch(lifedexOverviewProvider);
    final achievements = ref.watch(achievementOverviewProvider);
    final titles = ref.watch(titleCollectionProvider);
    final achieved = achievements.value?.achievedCount;

    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('나의 기록', style: LqText.cardTitle),
          const SizedBox(height: 4),
          _RecordRow(
            leading: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LqColors.surfaceTile,
                borderRadius: LqShape.tileRadius,
                border: Border.all(
                  color: LqColors.ink,
                  width: LqShape.borderWidth,
                ),
              ),
              child: const LqImage(LqAssets.iconBackpack, width: 20),
            ),
            label: 'LifeDex 도감',
            caption: _caption(
              lifedex,
              (value) =>
                  '수집률 ${value.percent}% · ${value.ownedCount} / ${value.totalCount}',
            ),
            onTap: () => context.push('/lifedex'),
          ),
          const LqDashedDivider(),
          _RecordRow(
            leading: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LqColors.gold,
                shape: BoxShape.circle,
                border: Border.all(
                  color: LqColors.ink,
                  width: LqShape.borderWidth,
                ),
              ),
              child: Text(
                achieved == null ? '—' : '$achieved',
                style: LqText.badge.copyWith(
                  fontSize: 13,
                  color: LqColors.textPrimary,
                ),
              ),
            ),
            label: '업적 / 칭호',
            caption: _caption(
              achievements,
              (value) =>
                  '달성 ${value.achievedCount} / ${value.total}'
                  '${titles.hasValue ? ' · 칭호 ${titles.requireValue.titles.length}개 보유' : ''}',
            ),
            onTap: () => context.push('/achievements'),
          ),
        ],
      ),
    );
  }

  /// 진척 문구. 조회 실패를 빈 칸으로 두면 "아무것도 없다"로 읽히므로 구분해서 알린다.
  static String _caption<T>(AsyncValue<T> value, String Function(T) format) {
    if (value.hasError && !value.isLoading) return '현황을 불러오지 못했어요';
    if (!value.hasValue) return '불러오는 중이에요…';
    return format(value.requireValue);
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.leading,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final Widget leading;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $caption',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LqSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: LqText.bodySm),
                    const SizedBox(height: 2),
                    Text(caption, style: LqText.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: LqColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard();

  @override
  Widget build(BuildContext context) {
    return LqCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          _MenuRow(label: '프로필 수정', onTap: () => context.push('/profile/edit')),
          // "칭호 선택" 행은 제거했다. 칭호 변경은 업적 화면의 칭호 탭에서 한다.
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
  const _MenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

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
