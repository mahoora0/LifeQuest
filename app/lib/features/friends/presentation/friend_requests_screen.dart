import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/presentation/widgets/friend_widgets.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// S-19 받은 요청 (화면맵 2g).
///
/// 친구 목록 상단의 "동료 신청이 N건 도착했어요 ›" 배너에서 연다. 세그먼트를
/// 3개로 늘리지 않는 이유는 요청이 상태가 아니라 **처리할 일**이기 때문이다.
class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() =>
      _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  /// 0 = 받은 요청, 1 = 보낸 요청.
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(friendRequestsProvider);
    final box = requests.value;

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LqHeader(title: '친구 요청'),
            LqChipRow(
              labels: [
                '받은 요청 ${box?.received.length ?? 0}',
                '보낸 요청 ${box?.sent.length ?? 0}',
              ],
              selectedIndex: _segment,
              onSelected: (index) => setState(() => _segment = index),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LqAsyncView<FriendRequestBox>(
                value: requests,
                onRetry: () =>
                    ref.read(friendRequestsProvider.notifier).refresh(),
                notReadyMessage: '동료 신청은 아직 준비 중이에요',
                notReadyHint: '동료 찾기에서 코드를 나눠 둘 수 있어요.',
                data: (value) => _segment == 0
                    ? _ReceivedTab(
                        requests: value.received,
                        onRespond: _respond,
                      )
                    : _SentTab(requests: value.sent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(int userId, {required bool accept}) async {
    try {
      await ref
          .read(friendRequestsProvider.notifier)
          .respond(userId, accept: accept);
      if (!mounted) return;
      // 거절은 조용히 처리한다 — 알림을 띄우면 상대에게 알린 것처럼 읽힌다.
      if (accept) showLqSnack(context, '이제 함께 모험해요!');
    } catch (error) {
      if (mounted) showLqError(context, error);
    }
  }
}

class _ReceivedTab extends StatelessWidget {
  const _ReceivedTab({required this.requests, required this.onRespond});

  final List<FriendRequest> requests;
  final void Function(int userId, {required bool accept}) onRespond;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyBox(message: '요청을 모두 처리하면\n이 자리가 비어요');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LqSpacing.screen,
        4,
        LqSpacing.screen,
        24,
      ),
      children: [
        for (final request in requests) ...[
          _RequestCard(
            request: request,
            onAccept: () => onRespond(request.userId, accept: true),
            onDecline: () => onRespond(request.userId, accept: false),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// 보낸 요청.
///
// TODO(design): 시안은 세그먼트만 그리고 보낸 요청 목록의 모습을 정하지 않았다.
//  받은 요청과 같은 행을 쓰되 처리 버튼 없이 대기 상태만 보여 둔다. 취소를
//  허용할지는 결정 필요 — 취소가 상대에게 어떻게 보이는지부터 정해야 한다.
class _SentTab extends StatelessWidget {
  const _SentTab({required this.requests});

  final List<FriendRequest> requests;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyBox(message: '아직 보낸 신청이 없어요');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LqSpacing.screen,
        4,
        LqSpacing.screen,
        24,
      ),
      children: [
        for (final request in requests) ...[
          LqCard(
            radius: LqShape.rowRadius,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                LqAvatar(nickname: request.nickname, seed: request.userId),
                const SizedBox(width: 10),
                Expanded(
                  child: LqAdventurerIdentity(
                    nickname: request.nickname,
                    level: request.level,
                    statusLine: request.statusLine,
                  ),
                ),
                const SizedBox(width: 8),
                const LqStatePill(label: '수락 대기'),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      radius: LqShape.rowRadius,
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Column(
        children: [
          Row(
            children: [
              LqAvatar(
                nickname: request.nickname,
                seed: request.userId,
                size: 44,
                fontSize: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LqAdventurerIdentity(
                  nickname: request.nickname,
                  level: request.level,
                  statusLine: request.statusLine,
                  nameStyle: LqText.cardTitle.copyWith(fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // "수락"이 아니라 "함께하기" — 격려 우선 원칙과 길드 어휘에 맞춘다.
              Expanded(
                child: LqButton(
                  label: '함께하기',
                  height: 42,
                  fontSize: 16,
                  onPressed: onAccept,
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 96,
                child: LqButton(
                  label: '거절',
                  height: 42,
                  fontSize: 16,
                  background: LqColors.surfacePanel,
                  foreground: LqColors.textSecondary,
                  shadow: false,
                  onPressed: onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LqImage(LqAssets.charPlainSit, width: 118),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LqText.bodySm.copyWith(color: LqColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
