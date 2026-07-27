import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 아바타 원형 배경 — 태그 팔레트의 배경색을 순환해서 쓴다(LifeDex 블롭과 같은 방식).
const _avatarColors = <Color>[
  Color(0xFFF3E4C8),
  Color(0xFFE4E9EC),
  Color(0xFFDFEAD1),
  Color(0xFFEADFF3),
  Color(0xFFE9E9D4),
];

Color _avatarColorFor(int id) => _avatarColors[id.abs() % _avatarColors.length];

/// 순위 메달 색. 1위는 브랜드 골드를 그대로 쓰고 2·3위만 이 화면 전용 색이다.
const _silver = Color(0xFFDDD6C4);
const _bronze = Color(0xFFE0B48C);

/// 본인 랭킹 행 강조 배경.
const _selfRowBackground = Color(0xFFF3E4C8);

/// S-18~22 친구. 한 화면에서 세그먼트 두 개로 목록과 랭킹을 오간다.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  /// 0 = 친구 목록, 1 = 이번 주 랭킹.
  int _segment = 0;

  static const _segments = ['친구 목록', '이번 주 랭킹'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LqHeader(
              title: '친구',
              showBack: false,
              // 친구 추가는 서버 연동 후 열린다. 홈의 알림 버튼과 같이 시각 요소만 둔다.
              trailing: LqIconButton(
                icon: Icons.person_add_alt,
                size: 26,
                iconSize: 15,
                semanticLabel: '친구 추가',
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

    return LqAsyncView<FriendList>(
      value: friends,
      onRetry: () => ref.read(friendListProvider.notifier).refresh(),
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
              style: LqText.bodySm,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onCheer});

  final Friend friend;
  final VoidCallback onCheer;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      radius: LqShape.rowRadius,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _Avatar(nickname: friend.nickname, seed: friend.userId),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        friend.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LqText.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: LqColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lv.${friend.level}',
                      style: LqText.caption.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LqColors.primary,
                      ),
                    ),
                  ],
                ),
                if (friend.statusLine != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    friend.statusLine!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LqText.caption,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CheerButton(cheered: friend.cheered, onTap: onCheer),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.nickname, required this.seed});

  final String nickname;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _avatarColorFor(seed),
        shape: BoxShape.circle,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: Text(
        nickname.isEmpty ? '?' : nickname.characters.first,
        style: LqText.cardTitle.copyWith(fontSize: 17),
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
        onTap: cheered ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LqSpacing.minTouchTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            height: 30,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                fontSize: 12.5,
                color: cheered ? LqColors.textPrimary : LqColors.primary,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        children: [
          Text(
            '친구 코드로 추가',
            style: LqText.bodySm.copyWith(fontWeight: FontWeight.w700),
          ),
          if (myCode != null) ...[
            const SizedBox(height: 4),
            Text('내 코드 · $myCode', style: LqText.caption),
          ],
        ],
      ),
    );
  }
}

class _RankingTab extends ConsumerWidget {
  const _RankingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(weeklyRankingProvider);

    return LqAsyncView<WeeklyRanking>(
      value: ranking,
      isEmpty: (value) => value.isEmpty,
      emptyMessage: '아직 이번 주 기록이 없어요',
      onRetry: () => ref.invalidate(weeklyRankingProvider),
      data: (value) => ListView(
        padding: const EdgeInsets.fromLTRB(
          LqSpacing.screen,
          4,
          LqSpacing.screen,
          24,
        ),
        children: [
          _RankSummaryCard(ranking: value),
          const SizedBox(height: LqSpacing.gap),
          for (final entry in value.entries) ...[
            _RankRow(entry: entry),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(
            '랭킹은 매주 월요일 0시에 초기화돼요',
            textAlign: TextAlign.center,
            style: LqText.caption,
          ),
        ],
      ),
    );
  }
}

class _RankSummaryCard extends StatelessWidget {
  const _RankSummaryCard({required this.ranking});

  final WeeklyRanking ranking;

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
                Text('이번 주 내 순위', style: LqText.caption),
                const SizedBox(height: 2),
                Text(
                  me == null
                      ? '아직 순위에 없어요'
                      : '${me.rank}위 (친구 ${ranking.friendCount}명 중)',
                  style: LqText.cardTitle,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: LqColors.gold,
        borderRadius: LqShape.pillRadius,
        border: Border.all(color: LqColors.ink, width: 1.6),
      ),
      child: Text(
        '${up ? '▲' : '▼'} ${delta.abs()}',
        style: LqText.badge.copyWith(
          fontSize: 12,
          color: LqColors.textPrimary,
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry});

  final RankEntry entry;

  Color get _medalColor => switch (entry.rank) {
    1 => LqColors.gold,
    2 => _silver,
    3 => _bronze,
    _ => LqColors.surfaceTile,
  };

  @override
  Widget build(BuildContext context) {
    return LqCard(
      radius: LqShape.rowRadius,
      background: entry.isMe ? _selfRowBackground : LqColors.surfaceTile,
      borderColor: entry.isMe ? LqColors.ink : LqColors.divider,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _medalColor,
              shape: BoxShape.circle,
              border: Border.all(color: LqColors.ink, width: 1.6),
            ),
            child: Text(
              '${entry.rank}',
              style: LqText.badge.copyWith(
                fontSize: 13,
                color: LqColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LqText.bodySm.copyWith(
                fontWeight: entry.isMe ? FontWeight.w700 : FontWeight.w400,
                color: LqColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
            decoration: const BoxDecoration(
              color: LqColors.expBadge,
              borderRadius: LqShape.pillRadius,
            ),
            child: Text(
              'EXP ${entry.weeklyExp}',
              style: LqText.badge.copyWith(color: LqColors.onDark),
            ),
          ),
        ],
      ),
    );
  }
}
