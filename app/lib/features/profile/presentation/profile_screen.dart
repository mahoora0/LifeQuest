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
import 'package:life_quest/shared/error/lq_error_messages.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_progress_bar.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 배지·아이콘 타일의 채움색. 카드 배경(tint)보다 한 단계 진해 타일이 도드라진다.
const _tileFill = Color(0xFFF3E9D0);

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
    ..invalidate(titleCollectionProvider)
    ..invalidate(badgeCollectionProvider);

  await Future.wait([
    _settle(ref.read(myProfileProvider.future)),
    _settle(ref.read(levelStatusProvider.future)),
    _settle(ref.read(rewardHistoryProvider.future)),
    _settle(ref.read(questHistoryProvider.future)),
    _settle(ref.read(lifedexOverviewProvider.future)),
    _settle(ref.read(achievementOverviewProvider.future)),
    _settle(ref.read(titleCollectionProvider.future)),
    _settle(ref.read(badgeCollectionProvider.future)),
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
                const _RecentRewardCard(),
                const SizedBox(height: LqSpacing.gap),
                const _ExpCard(),
                // ① 재화 2칸은 서버에 재화가 없어 v1에서 노출하지 않는다.
                const SizedBox(height: LqSpacing.gap),
                const _GrowthRecordCard(),
                const SizedBox(height: LqSpacing.gap),
                const _BadgeCard(),
                const SizedBox(height: LqSpacing.gap),
                const _MyRecordCard(),
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

/// "최근 획득" — 마지막에 얻은 보상 몇 건.
///
/// 캐릭터 카드가 있던 자리다. 캐릭터는 헤더 아바타에 이미 그려지고 변경도 프로필
/// 수정에서만 되기 때문에, 이 자리에는 방금 무엇을 얻었는지 알려주는 편이 읽을 값이
/// 있다. 종류별 전체 목록은 업적 화면의 칭호·배지 탭이 맡는다.
class _RecentRewardCard extends ConsumerWidget {
  const _RecentRewardCard();

  static const _maxRows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardHistoryProvider);
    final entries = rewards.value?.recent ?? const <RewardEntry>[];

    return LqCard(
      background: LqColors.surfaceCard,
      header: '최근 획득',
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 새로고침 중에도 이전 목록을 유지한다 — 값이 있으면 상태 표시로 갈아끼우지 않는다.
          if (!rewards.hasValue && rewards.isLoading)
            const LinearProgressIndicator(minHeight: 3)
          else if (!rewards.hasValue && rewards.hasError)
            Text('보상 이력을 불러오지 못했어요.', style: LqText.caption)
          else if (entries.isEmpty)
            Text('아직 획득한 보상이 없어요.', style: LqText.caption)
          else
            for (final entry in entries.take(_maxRows))
              _RewardRow(entry: entry),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.entry});

  final RewardEntry entry;

  @override
  Widget build(BuildContext context) {
    final when = _relativeDay(entry.acquiredAt);
    final kind = _kindLabel(entry.kind);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _tileFill,
              borderRadius: LqShape.tileRadius,
              border: Border.all(
                color: LqColors.ink,
                width: LqShape.borderWidth,
              ),
            ),
            child: Icon(
              _kindIcon(entry.kind),
              size: 16,
              color: LqColors.primary,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LqText.bodySm,
                ),
                const SizedBox(height: 1),
                Text(
                  when.isEmpty ? kind : '$kind · $when',
                  style: LqText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _kindIcon(RewardKind kind) => switch (kind) {
  RewardKind.title => Icons.military_tech_outlined,
  RewardKind.badge => Icons.workspace_premium_outlined,
  RewardKind.item => Icons.card_giftcard_rounded,
};

String _kindLabel(RewardKind kind) => switch (kind) {
  RewardKind.title => '칭호',
  RewardKind.badge => '배지',
  RewardKind.item => '아이템',
};

/// 획득 시각을 "오늘 / 어제 / N일 전 / M월 D일"로 읽는다.
/// 이 카드에서는 정확한 시각보다 얼마나 최근인지가 중요하다.
String _relativeDay(DateTime? value) {
  if (value == null) return '';

  final date = value.toLocal();
  final now = DateTime.now();
  // 시각이 아니라 날짜 경계로 센다 — 밤 11시에 받은 보상이 한 시간 뒤 "어제"가 되어야 한다.
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;

  if (days <= 0) return '오늘';
  if (days == 1) return '어제';
  if (days < 7) return '$days일 전';
  return '${date.month}월 ${date.day}일';
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
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: LqColors.surfaceTint,
            shape: BoxShape.circle,
            border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
          ),
          // 사진을 올리기 전 기본 아바타는 시안대로 정면 캐릭터를 쓴다.
          child: imageUrl.isEmpty
              ? const LqImage(LqAssets.charFront, width: 52)
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const LqImage(LqAssets.charFront, width: 52),
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
              Row(
                children: [
                  // 대표 배지는 업적 화면 배지 탭에서 지정한다. 지정 화면과 표시 화면이
                  // 떨어져 있어, 여기에 나타나지 않으면 지정이 먹혔는지 알 길이 없다.
                  if (profile.representativeBadge != null) ...[
                    _RepresentativeBadge(name: profile.representativeBadge!),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      profile.representativeTitle ?? '대표 칭호 없음',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LqText.bodySm.copyWith(
                        fontSize: 14.5,
                        color: profile.representativeTitle == null
                            ? LqColors.textMuted
                            : LqColors.primary,
                      ),
                    ),
                  ),
                ],
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

/// 헤더에 붙는 대표 배지 표식. 배지 탭의 선택 상태와 같은 색 언어(gold)를 쓴다.
class _RepresentativeBadge extends StatelessWidget {
  const _RepresentativeBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '대표 배지 $name',
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LqColors.gold,
          shape: BoxShape.circle,
          border: Border.all(color: LqColors.ink, width: 1.6),
        ),
        child: Text(
          name.isEmpty ? '?' : name.characters.first,
          style: LqText.badge.copyWith(fontSize: 12, color: LqColors.goldText),
        ),
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

    final cells = <Widget>[
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
        value: level.value == null ? '—' : '${level.requireValue.totalExp}',
      ),
    ];

    return LqCard(
      background: LqColors.surfaceCard,
      header: '성장 기록',
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const LqDashedDivider(axis: Axis.vertical),
              cells[i],
            ],
          ],
        ),
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
    // 시안은 라벨이 위, 숫자가 아래다 — 먼저 무엇의 수치인지 읽고 값을 본다.
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: LqText.caption),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LqText.levelNumber.copyWith(fontSize: 23),
          ),
        ],
      ),
    );
  }
}

/// "내 배지" — 보유 배지 4칸 미리보기. 시안 9번 화면에 "나의 기록"과 나란히 있다.
///
/// 여기서는 대표 지정을 하지 않고 "더보기"로 업적 화면의 배지 탭에 넘긴다.
/// 지정 로직이 두 곳에 생기면 낙관적 갱신과 롤백을 양쪽에서 관리해야 한다.
/// 대신 지정된 대표는 첫 칸으로 끌어와 표시해, 지정이 반영됐는지 여기서 확인된다.
class _BadgeCard extends ConsumerWidget {
  const _BadgeCard();

  static const _slotCount = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(badgeCollectionProvider);
    final badges = collection.value?.badges ?? const <ProfileItem>[];
    final representativeId = collection.value?.representativeBadgeId;

    // 대표 배지를 앞으로 끌어와 4칸 미리보기에서 밀려나지 않게 한다.
    // 다섯 번째 배지를 대표로 지정했는데 이 카드가 그대로면 지정이 먹혔는지 알 수 없다.
    final items = representativeId == null
        ? badges
        : [
            ...badges.where((badge) => badge.id == representativeId),
            ...badges.where((badge) => badge.id != representativeId),
          ];

    return LqCard(
      background: LqColors.surfaceCard,
      header: '내 배지',
      headerTrailing: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/achievements?tab=badges'),
        child: Text('더보기 ›', style: LqText.caption),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          for (var i = 0; i < _slotCount; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _BadgeSlot(
              item: i < items.length ? items[i] : null,
              // id가 없는 배지끼리 null == null로 맞아떨어지지 않게 대표 id를 먼저 확인한다.
              representative:
                  representativeId != null &&
                  i < items.length &&
                  items[i].id == representativeId,
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeSlot extends StatelessWidget {
  const _BadgeSlot({required this.item, this.representative = false});

  final ProfileItem? item;

  /// 대표로 지정된 배지. 배지 탭의 선택 상태와 같은 gold를 쓴다.
  final bool representative;

  @override
  Widget build(BuildContext context) {
    final badge = item;

    return Semantics(
      // 색만으로 대표를 구분하면 읽어 주는 화면에서는 전달되지 않는다.
      label: badge == null
          ? '빈 배지 칸'
          : representative
          ? '대표 배지 ${badge.name}'
          : badge.name,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: badge == null
              ? LqColors.lockedBg
              : representative
              ? LqColors.gold
              : _tileFill,
          borderRadius: LqShape.tileRadius,
          border: Border.all(
            color: badge == null ? LqColors.borderMuted : LqColors.ink,
            width: LqShape.borderWidth,
          ),
        ),
        child: Text(
          badge == null ? '?' : badge.name.characters.first,
          maxLines: 1,
          style: LqText.badge.copyWith(
            fontSize: 17,
            color: badge == null
                ? LqColors.textMuted
                : representative
                ? LqColors.goldText
                : LqColors.textPrimary,
          ),
        ),
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
      header: '나의 기록',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecordRow(
            leading: const _RecordTile(asset: LqAssets.iconMap, width: 26),
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
                  fontSize: 15,
                  color: LqColors.goldText,
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
  ///
  /// 서버가 아직 없는 구간은 "불러오지 못했다"가 아니다 — 재시도를 기대하게 만들면
  /// 안 되므로 준비 중으로 구분한다.
  static String _caption<T>(AsyncValue<T> value, String Function(T) format) {
    if (value.hasError && !value.isLoading) {
      return isFeatureNotReady(value.error!) ? '준비 중이에요' : '현황을 불러오지 못했어요';
    }
    if (!value.hasValue) return '불러오는 중이에요…';
    return format(value.requireValue);
  }
}

/// "나의 기록" 행 앞의 아이콘 타일. 시안은 카드 배경보다 진한 채움을 쓴다.
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.asset, required this.width});

  final String asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _tileFill,
        borderRadius: LqShape.tileRadius,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: LqImage(asset, width: width),
    );
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
      background: LqColors.surfaceCard,
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
