import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/presentation/widgets/friend_widgets.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_hero_tags.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 순위 메달 색. 1위는 브랜드 골드를 그대로 쓰고 2·3위만 이 화면 전용 색이다.
const _silver = Color(0xFFDDD6C4);
const _bronze = Color(0xFFE0B48C);

/// 본인 랭킹 행 강조 배경.
const _selfRowBackground = Color(0xFFF3E4C8);

/// 주간 EXP는 네 자리를 넘기므로 시안대로 천 단위를 끊어 읽기 쉽게 한다.
String _thousands(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (match) => '${match[1]},',
);

/// S-18~22 친구. 한 화면에서 세그먼트 두 개로 목록과 랭킹을 오간다.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  /// 0 = 친구 목록, 1 = 이번 주 랭킹.
  int _segment = 0;

  static const _segments = ['친구 목록', '랭킹'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LqHeader(
              title: '친구',
              showBack: false,
              trailing: LqIconButton(
                icon: Icons.person_add_alt,
                size: 32,
                iconSize: 18,
                semanticLabel: '동료 찾기',
                onTap: () => context.push('/friends/search'),
              ),
            ),
            LqChipRow(
              labels: _segments,
              selectedIndex: _segment,
              onSelected: (index) => setState(() => _segment = index),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _segment == 0
                  ? const _FriendListTab()
                  : const _RankingTab(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendListTab extends ConsumerWidget {
  const _FriendListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendListProvider);

    // 받은 요청 배너는 목록 조회 밖에 둔다. 안에 두면 목록이 실패·준비 중일 때
    // /friends/requests로 가는 유일한 문이 함께 사라진다.
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: LqSpacing.screen),
          child: _RequestBanner(),
        ),
        Expanded(child: _list(context, ref, friends)),
      ],
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<FriendList> friends,
  ) {
    return LqAsyncView<FriendList>(
      value: friends,
      onRetry: () => ref.read(friendListProvider.notifier).refresh(),
      notReadyMessage: '친구 목록은 아직 준비 중이에요',
      notReadyHint: '동료 찾기에서 친구 코드를 미리 나눠 둘 수 있어요.',
      // 빈 상태로 갈아끼우지 않는다. 친구가 없을수록 아래 코드 카드가 필요하다.
      data: (value) => RefreshIndicator(
        color: LqColors.primary,
        backgroundColor: LqColors.surfaceRaised,
        onRefresh: () => ref.read(friendListProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            LqSpacing.screen,
            4,
            LqSpacing.screen,
            24,
          ),
          children: [
            _IntroCard(friendCount: value.friends.length),
            const SizedBox(height: LqSpacing.gap),
            for (final friend in value.friends) ...[
              _FriendRow(
                friend: friend,
                onCheer: () => _cheer(context, ref, friend),
                onOpen: () => context.push('/friends/${friend.userId}'),
              ),
              const SizedBox(height: 10),
            ],
            _FriendCodeCard(myCode: value.myCode),
          ],
        ),
      ),
    );
  }

  Future<void> _cheer(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) async {
    try {
      await ref.read(friendListProvider.notifier).cheer(friend.userId);
    } catch (error) {
      if (context.mounted) showLqError(context, error);
    }
  }
}

/// "동료 신청이 N건 도착했어요 ›" — 받은 요청이 있을 때만 목록 위에 뜬다.
///
/// 요청은 상태가 아니라 처리할 일이라 세그먼트가 아닌 배너로 띄운다.
/// 요청이 없으면 자리도 차지하지 않는다.
class _RequestBanner extends ConsumerWidget {
  const _RequestBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 조회에 실패해도 배너만 조용히 사라진다. 목록 자체를 막을 값이 아니다.
    final box = ref.watch(friendRequestsProvider).value;
    final receivedCount = box?.receivedCount ?? 0;
    final sentCount = box?.sent.length ?? 0;
    final hasReceived = receivedCount > 0;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: LqSpacing.gap),
      child: LqCard(
        radius: LqShape.rowRadius,
        background: hasReceived ? LqColors.goldBg : LqColors.surfaceCard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        onTap: () => context.push('/friends/requests'),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasReceived ? LqColors.accent : LqColors.tileFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: LqColors.ink,
                  width: LqShape.borderWidth,
                ),
              ),
              child: hasReceived
                  ? Text(
                      '$receivedCount',
                      style: LqText.badge.copyWith(
                        fontSize: 13,
                        color: LqColors.onDark,
                      ),
                    )
                  : const Icon(
                      Icons.outbox_rounded,
                      size: 15,
                      color: LqColors.textPrimary,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasReceived ? '친구 요청이 $receivedCount건 도착했어요' : '친구 요청 관리',
                    style: LqText.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hasReceived
                          ? LqColors.goldText
                          : LqColors.textPrimary,
                    ),
                  ),
                  Text('보낸 요청 $sentCount건 확인', style: LqText.caption),
                ],
              ),
            ),
            Text(
              '›',
              style: LqText.cardTitle.copyWith(
                color: hasReceived ? LqColors.goldText : LqColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.friendCount});

  final int friendCount;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const LqImage(LqAssets.charWave, width: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              friendCount == 0
                  ? '아직 친구가 없어요.\n친구 코드를 나누고 함께 모험해요!'
                  : '친구 $friendCount명이 오늘도 모험 중!\n응원하면 서로 EXP 5!',
              style: LqText.bodySm.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.onCheer,
    required this.onOpen,
  });

  final Friend friend;
  final VoidCallback onCheer;

  /// 행 전체가 동료의 여정(S-21)으로 가는 문이다.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      radius: LqShape.rowRadius,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      onTap: onOpen,
      child: Row(
        children: [
          LqAvatar(
            nickname: friend.nickname,
            seed: friend.userId,
            imageUrl: friend.profileImageUrl,
            // 여정 화면의 큰 아바타로 그대로 이어진다.
            heroTag: LqHeroTags.adventurer(friend.userId),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LqAdventurerIdentity(
              nickname: friend.nickname,
              level: friend.level,
              statusLine: friend.statusLine,
            ),
          ),
          const SizedBox(width: 8),
          _CheerButton(cheered: friend.cheered, onTap: onCheer),
        ],
      ),
    );
  }
}

/// 응원 버튼. 되돌리기가 없는 단방향 동작이라 누른 뒤에는 비활성 표시로 남는다.
class _CheerButton extends StatelessWidget {
  const _CheerButton({required this.cheered, required this.onTap});

  final bool cheered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !cheered,
      label: cheered ? '응원함' : '응원하기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 행 전체가 동료의 여정으로 가는 문이 됐으므로 이 버튼은 탭을 삼켜야 한다.
        // 이미 응원한 뒤에도 빈 콜백을 둬서 제스처 경쟁에서 이기게 한다 —
        // null로 두면 부모가 탭을 가져가 응원 자리를 눌렀는데 화면이 넘어간다.
        onTap: cheered ? () {} : onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LqSpacing.minTouchTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
            decoration: BoxDecoration(
              color: cheered ? LqColors.gold : LqColors.surfaceTile,
              borderRadius: LqShape.pillRadius,
              border: Border.all(
                color: LqColors.ink,
                width: LqShape.borderWidth,
              ),
            ),
            child: Text(
              cheered ? '응원함 ✓' : '응원',
              style: LqText.badge.copyWith(
                fontSize: 11,
                color: cheered ? LqColors.goldText : LqColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendCodeCard extends StatelessWidget {
  const _FriendCodeCard({required this.myCode});

  final String? myCode;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      locked: true,
      radius: LqShape.rowRadius,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // 코드 카드의 ›는 동료 찾기(코드 입력)로 간다. 헤더 +와 같은 곳이지만
      // 코드를 들고 있는 사람은 여기서 바로 들어오는 흐름이 자연스럽다.
      onTap: () => context.push('/friends/search'),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: LqColors.borderMuted,
                width: LqShape.borderWidth,
              ),
            ),
            child: Text(
              '+',
              style: LqText.badge.copyWith(
                fontSize: 17,
                color: LqColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '친구 코드로 추가',
                  style: LqText.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: LqColors.textBody,
                  ),
                ),
                if (myCode != null) ...[
                  const SizedBox(height: 2),
                  Text('내 코드 · $myCode', style: LqText.caption),
                ],
              ],
            ),
          ),
          if (myCode != null)
            LqStatePill(
              label: '복사',
              tone: LqPillTone.quiet,
              fontSize: 11,
              onTap: () => _copy(context, myCode!),
            )
          else
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: LqColors.textMuted,
            ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) showLqSnack(context, '친구 코드를 복사했어요');
  }
}

class _RankingTab extends ConsumerStatefulWidget {
  const _RankingTab();

  @override
  ConsumerState<_RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends ConsumerState<_RankingTab> {
  RankingType _type = RankingType.exp;
  RankingScope _scope = RankingScope.global;

  @override
  Widget build(BuildContext context) {
    final query = (scope: _scope, type: _type);
    final ranking = ref.watch(weeklyRankingProvider(query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LqSpacing.screen),
          child: Row(
            children: [
              Text('랭킹 범위', style: LqText.label),
              const Spacer(),
              LqStatePill(
                label: '전체',
                tone: _scope == RankingScope.global
                    ? LqPillTone.primary
                    : LqPillTone.quiet,
                onTap: () => setState(() => _scope = RankingScope.global),
              ),
              const SizedBox(width: 6),
              LqStatePill(
                label: '친구',
                tone: _scope == RankingScope.friends
                    ? LqPillTone.primary
                    : LqPillTone.quiet,
                onTap: () => setState(() => _scope = RankingScope.friends),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LqSpacing.screen),
          child: _RankingTypeSwitch(
            selected: _type,
            onSelected: (type) => setState(() => _type = type),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LqAsyncView<WeeklyRanking>(
            value: ranking,
            isEmpty: (value) => value.isEmpty,
            emptyMessage: '아직 랭킹 기록이 없어요',
            onRetry: () => ref.invalidate(weeklyRankingProvider(query)),
            notReadyMessage: '랭킹은 아직 준비 중이에요',
            data: (value) => ListView(
              padding: const EdgeInsets.fromLTRB(
                LqSpacing.screen,
                4,
                LqSpacing.screen,
                24,
              ),
              children: [
                _RankSummaryCard(ranking: value, scope: _scope, type: _type),
                const SizedBox(height: LqSpacing.gap),
                for (final entry in value.entries) ...[
                  _RankRow(
                    entry: entry,
                    type: _type,
                    // 랭킹 행도 친구 행과 같은 화면으로 보낸다. 본인 행은 비교할
                    // 상대가 없으므로 열지 않는다.
                    onOpen: entry.isMe || _scope == RankingScope.global
                        ? null
                        : () => context.push('/friends/${entry.userId}'),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                Text(
                  _type == RankingType.exp
                      ? '누적 EXP가 높은 순서로 표시돼요'
                      : '레벨이 높은 순서로 표시돼요',
                  textAlign: TextAlign.center,
                  style: LqText.caption,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingTypeSwitch extends StatelessWidget {
  const _RankingTypeSwitch({required this.selected, required this.onSelected});

  final RankingType selected;
  final ValueChanged<RankingType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LqColors.surfaceTile,
        borderRadius: LqShape.rowRadius,
        border: Border.all(color: LqColors.borderMuted),
      ),
      child: Row(
        children: [
          _RankingTypeButton(
            label: 'EXP 랭킹',
            icon: Icons.bolt_rounded,
            selected: selected == RankingType.exp,
            onTap: () => onSelected(RankingType.exp),
          ),
          _RankingTypeButton(
            label: '레벨 랭킹',
            icon: Icons.military_tech_outlined,
            selected: selected == RankingType.level,
            onTap: () => onSelected(RankingType.level),
          ),
        ],
      ),
    );
  }
}

class _RankingTypeButton extends StatelessWidget {
  const _RankingTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: selected ? LqColors.primary : Colors.transparent,
              borderRadius: LqShape.tileRadius,
              border: selected ? Border.all(color: LqColors.ink) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? LqColors.onDark : LqColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: LqText.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? LqColors.onDark : LqColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankSummaryCard extends StatelessWidget {
  const _RankSummaryCard({
    required this.ranking,
    required this.scope,
    required this.type,
  });

  final WeeklyRanking ranking;
  final RankingScope scope;
  final RankingType type;

  @override
  Widget build(BuildContext context) {
    final me = ranking.me;
    final delta = ranking.rankDelta;

    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const LqImage(LqAssets.charFront, width: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == RankingType.exp ? '내 EXP 순위' : '내 레벨 순위',
                  style: LqText.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: LqColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                if (me == null)
                  Text('아직 순위에 없어요', style: LqText.cardTitle)
                else
                  // 순위 숫자를 키우고 모수는 작게 — 먼저 읽어야 할 값이 순위다.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${me.rank}위 ',
                          style: LqText.levelNumber.copyWith(fontSize: 23),
                        ),
                        TextSpan(
                          text: scope == RankingScope.global
                              ? '/ 전체 ${ranking.totalElements ?? ranking.entries.length}명 중'
                              : '/ 친구 ${ranking.friendCount}명 중',
                          style: LqText.caption.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // 지난주 집계가 없으면 등락을 만들어내지 않고 감춘다.
          if (delta != null && delta != 0) _DeltaPill(delta: delta),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: LqColors.gold,
        borderRadius: LqShape.pillRadius,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: Text(
        '${up ? '↑' : '↓'} ${delta.abs()}',
        style: LqText.badge.copyWith(fontSize: 13, color: LqColors.goldText),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.type, this.onOpen});

  final RankEntry entry;
  final RankingType type;
  final VoidCallback? onOpen;

  Color get _medalColor => switch (entry.rank) {
    1 => LqColors.gold,
    2 => _silver,
    3 => _bronze,
    _ => LqColors.surfaceTile,
  };

  @override
  Widget build(BuildContext context) {
    return LqCard(
      // 랭킹 행은 카드가 아니라 타일 크기의 행이라 시안의 12/15 라운드를 쓴다.
      radius: LqShape.tileRadius,
      background: entry.isMe ? _selfRowBackground : LqColors.surfaceTile,
      borderColor: entry.isMe ? LqColors.ink : LqColors.divider,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      onTap: onOpen,
      child: Row(
        children: [
          _RankCircle(rank: entry.rank, color: _medalColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LqText.cardTitle,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            decoration: const BoxDecoration(
              color: LqColors.expBadge,
              borderRadius: LqShape.pillRadius,
            ),
            child: Text(
              type == RankingType.exp
                  ? 'EXP ${_thousands(entry.weeklyExp)}'
                  : 'Lv. ${entry.level}',
              style: LqText.badge.copyWith(
                fontSize: 12.5,
                color: LqColors.onDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankCircle extends StatelessWidget {
  const _RankCircle({required this.rank, required this.color});

  final int rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            strutStyle: const StrutStyle(
              fontSize: 11,
              height: 1,
              forceStrutHeight: true,
            ),
            style: LqText.badge.copyWith(
              fontSize: 11,
              height: 1,
              color: LqColors.goldText,
            ),
          ),
        ),
      ),
    );
  }
}
