import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/presentation/widgets/friend_widgets.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_icon.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// S-18 동료 찾기 (화면맵 2f).
///
/// 친구 헤더의 + 와 친구 코드 카드의 › 에서 연다(둘 다 시안 점검에서 죽은
/// 컨트롤로 지목된 것들이다).
class FriendSearchScreen extends ConsumerStatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  ConsumerState<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends ConsumerState<FriendSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(adventurerSearchProvider);
    final myCode = ref.watch(myFriendCodeProvider).value;

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LqHeader(title: '동료 찾기'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LqSpacing.screen,
                0,
                LqSpacing.screen,
                LqSpacing.gap,
              ),
              child: Column(
                children: [
                  _SearchField(
                    controller: _controller,
                    onSubmitted: _search,
                    onCleared: _clear,
                  ),
                  const SizedBox(height: LqSpacing.gap),
                  _MyCodeCard(code: myCode),
                ],
              ),
            ),
            Expanded(
              child: LqAsyncView<AdventurerSearchState>(
                value: search,
                notReadyMessage: '동료 찾기는 아직 준비 중이에요',
                notReadyHint: '내 코드를 나누면 상대가 먼저 찾아올 수 있어요.',
                onRetry: () => _search(_controller.text),
                data: (value) => value.hasQuery
                    ? _Results(
                        state: value,
                        onRequest: (userId) => _request(userId),
                      )
                    : const _Prompt(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _search(String query) {
    ref.read(adventurerSearchProvider.notifier).search(query);
  }

  void _clear() {
    _controller.clear();
    ref.read(adventurerSearchProvider.notifier).search('');
  }

  Future<void> _request(int userId) async {
    try {
      await ref.read(adventurerSearchProvider.notifier).sendRequest(userId);
      if (mounted) showLqSnack(context, '동료 신청을 보냈어요');
    } catch (error) {
      if (mounted) showLqError(context, error);
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      decoration: BoxDecoration(
        color: LqColors.surfacePanel,
        borderRadius: LqShape.rowRadius,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: Row(
        children: [
          const LqIcon(
            LqIcons.search,
            size: 18,
            color: LqColors.textSecondary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: LqText.body.copyWith(color: LqColors.textPrimary),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '닉네임이나 코드로 찾기',
                hintStyle: TextStyle(fontSize: 16, color: LqColors.textMuted),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: 4)
                : _ClearButton(onTap: onCleared),
          ),
        ],
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '검색어 지우기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: LqSpacing.minTouchTarget,
          height: LqSpacing.minTouchTarget,
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: LqColors.lockedTile,
                shape: BoxShape.circle,
              ),
              child: Text(
                '×',
                style: LqText.badge.copyWith(
                  fontSize: 12,
                  color: LqColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 내 친구 코드. 친구가 없을수록 이 카드가 필요하다.
class _MyCodeCard extends StatelessWidget {
  const _MyCodeCard({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LqColors.tileFill,
              shape: BoxShape.circle,
              border: Border.all(
                color: LqColors.ink,
                width: LqShape.borderWidth,
              ),
            ),
            child: Text(
              '#',
              style: LqText.badge.copyWith(
                fontSize: 15,
                color: LqColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code == null ? '내 코드를 불러오는 중이에요' : '내 코드 · $code',
                  style: LqText.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: LqColors.textBody,
                  ),
                ),
                const SizedBox(height: 2),
                Text('코드를 나누면 바로 찾을 수 있어요', style: LqText.caption),
              ],
            ),
          ),
          if (code != null) ...[
            const SizedBox(width: 8),
            LqStatePill(
              label: '복사',
              tone: LqPillTone.quiet,
              onTap: () => _copy(context, code!),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) showLqSnack(context, '코드를 복사했어요');
  }
}

/// 아직 검색하지 않은 상태. 빈 결과와 구분해야 "없다"는 오해가 없다.
class _Prompt extends StatelessWidget {
  const _Prompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LqImage(LqAssets.charSit, width: 118),
            const SizedBox(height: 14),
            Text(
              '함께할 동료의 닉네임을 적어 보세요',
              textAlign: TextAlign.center,
              style: LqText.body.copyWith(color: LqColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.onRequest});

  final AdventurerSearchState state;
  final ValueChanged<int> onRequest;

  @override
  Widget build(BuildContext context) {
    if (state.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LqImage(LqAssets.charPlainSit, width: 118),
              const SizedBox(height: 14),
              Text(
                '"${state.query}" 로는 아직 못 찾았어요',
                textAlign: TextAlign.center,
                style: LqText.body.copyWith(color: LqColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                '코드를 받아 적으면 정확하게 찾을 수 있어요',
                textAlign: TextAlign.center,
                style: LqText.caption,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LqSpacing.screen,
        0,
        LqSpacing.screen,
        24,
      ),
      children: [
        Text('검색 결과 ${state.results.length}명', style: LqText.caption),
        const SizedBox(height: 8),
        for (final result in state.results) ...[
          _ResultRow(result: result, onRequest: () => onRequest(result.userId)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.onRequest});

  final AdventurerSearchResult result;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final actionable = result.relation.isActionable;

    return LqCard(
      radius: LqShape.rowRadius,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Row(
        children: [
          LqAvatar(nickname: result.nickname, seed: result.userId),
          const SizedBox(width: 10),
          Expanded(
            child: LqAdventurerIdentity(
              nickname: result.nickname,
              level: result.level,
              statusLine: result.statusLine,
            ),
          ),
          const SizedBox(width: 8),
          LqStatePill(
            label: result.relation.actionLabel,
            tone: actionable ? LqPillTone.primary : LqPillTone.muted,
            onTap: actionable ? onRequest : null,
          ),
        ],
      ),
    );
  }
}
