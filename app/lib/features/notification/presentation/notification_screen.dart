import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/notification/application/notification_providers.dart';
import 'package:life_quest/features/notification/data/notification_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

/// 알림 아이콘 웰 배경 — 종류별로 한 톤씩 달리해 훑을 때 갈래가 보이게 한다.
const _kindTints = <LqNotificationKind, Color>{
  LqNotificationKind.achievement: LqColors.goldBg,
  LqNotificationKind.cheer: Color(0xFFDCE8C6),
  LqNotificationKind.friendRequest: Color(0xFFCFE3EC),
  LqNotificationKind.questAssigned: LqColors.successBg,
  LqNotificationKind.levelUp: Color(0xFFEADFF3),
};

/// 알림 목록 + 알림 설정 (화면맵 2d).
///
/// 홈 헤더의 알림 벨에서 연다. 설정은 목록 하단에 두고, 마이페이지의 "알림 설정"도
/// 같은 화면으로 보낸다 — 목록과 설정이 서로를 여는 문을 만들지 않는다.
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationFeedProvider);
    final unread = feed.value?.unreadCount ?? 0;

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 헤더는 본문과 분리한다 — 조회에 실패해도 돌아갈 길이 남아야 한다.
            LqHeader(
              title: '알림',
              trailing: _MarkAllReadButton(
                enabled: unread > 0,
                onTap: () => _markAllRead(context, ref),
              ),
            ),
            // 목록의 상태와 무관하게 설정 카드는 늘 그린다.
            //
            // 목록 조회 결과 안에 두면 빈 상태·준비 중·오류에서 통째로 사라지는데,
            // 하필 준비 중 안내가 "알림 설정은 아래에서 미리 정해 둘 수 있어요"라고
            // 그 카드를 가리킨다. 마이페이지의 "알림 설정" 행도 이 화면으로 오므로,
            // 그 진입점이 아무것도 없는 화면에서 끝나게 된다.
            Expanded(
              child: RefreshIndicator(
                color: LqColors.primary,
                backgroundColor: LqColors.surfaceRaised,
                onRefresh: () =>
                    ref.read(notificationFeedProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    LqSpacing.screen,
                    4,
                    LqSpacing.screen,
                    24,
                  ),
                  children: [
                    // 로딩·빈·오류가 카드 높이를 흔들지 않도록 일정한 자리를 차지한다.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 250),
                      child: LqAsyncView<LqNotificationFeed>(
                        value: feed,
                        onRetry: () => ref
                            .read(notificationFeedProvider.notifier)
                            .refresh(),
                        notReadyMessage: '알림은 아직 준비 중이에요',
                        notReadyHint: '알림 설정은 아래에서 미리 정해 둘 수 있어요.',
                        isEmpty: (value) => value.isEmpty,
                        emptyMessage: '새 소식이 없어요',
                        emptyAsset: LqAssets.charPlainSit,
                        data: (value) => Column(
                          children: [
                            for (final item in value.items) ...[
                              _NotificationRow(
                                item: item,
                                onTap: () => _open(context, ref, item),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const _SettingsCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationFeedProvider.notifier).markAllRead();
    } catch (error) {
      if (context.mounted) showLqError(context, error);
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    LqNotification item,
  ) async {
    final route = item.route;
    // 이동보다 읽음 처리가 먼저다 — 이동 후에 화면이 사라지면 실패를 알릴 곳이 없다.
    if (!item.read) {
      try {
        await ref.read(notificationFeedProvider.notifier).markRead(item.id);
      } catch (error) {
        if (context.mounted) showLqError(context, error);
        return;
      }
    }
    if (route != null && context.mounted) context.push(route);
  }
}

/// "모두 읽음" — 읽지 않은 것이 없으면 비활성으로 남긴다.
class _MarkAllReadButton extends StatelessWidget {
  const _MarkAllReadButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '모두 읽음',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        // `Container`에 `alignment`를 주면 **부모가 허용하는 최대 폭까지 커진다**.
        // 헤더는 Stack이라 그 최대치가 화면 폭이어서, 이 버튼이 제목 위를 덮고
        // 좌상단 뒤로 가기 자리까지 탭 영역으로 먹었다 — 뒤로 가려다 전체 읽음이
        // 실행됐다. `SizedBox` + `widthFactor: 1`로 글자 폭에만 맞춘다.
        child: SizedBox(
          height: LqSpacing.minTouchTarget,
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '모두 읽음',
                style: LqText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: enabled ? LqColors.primary : LqColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final LqNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.read;

    return LqCard(
      radius: LqShape.rowRadius,
      // 읽지 않음은 tint + ink 테두리, 읽음은 raised + soft 테두리로만 구분한다.
      background: unread ? LqColors.surfaceCard : LqColors.surfaceTile,
      borderColor: unread ? LqColors.ink : LqColors.divider,
      shadow: unread,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      onTap: onTap,
      child: Row(
        children: [
          _Leading(item: item),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: LqText.bodySm.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                    color: unread ? LqColors.textPrimary : LqColors.textBody,
                  ),
                ),
                const SizedBox(height: 2),
                Text(item.timeLabel, style: LqText.caption),
              ],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: LqColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 행 앞머리 표식 — 깃발 아이콘 · 이니셜 아바타 · 레벨 숫자 · 체크 글리프.
class _Leading extends StatelessWidget {
  const _Leading({required this.item});

  final LqNotification item;

  @override
  Widget build(BuildContext context) {
    final tint = _kindTints[item.kind] ?? LqColors.surfaceTile;
    final isAvatar =
        item.kind == LqNotificationKind.cheer ||
        item.kind == LqNotificationKind.friendRequest;

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        shape: isAvatar ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isAvatar ? null : LqShape.tileRadius,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: switch (item.kind) {
        LqNotificationKind.achievement => const LqImage(
          LqAssets.iconFlag,
          width: 18,
        ),
        LqNotificationKind.questAssigned => Text(
          '✓',
          style: LqText.badge.copyWith(fontSize: 15, color: LqColors.primary),
        ),
        _ => Text(
          item.leadingText ?? '·',
          style: LqText.badge.copyWith(fontSize: 14, color: LqColors.goldText),
        ),
      },
    );
  }
}

/// 알림 설정 — 목록 하단에 붙는다.
class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);

    return LqCard(
      header: '알림 설정',
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(14, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final channel in LqNotificationChannel.values)
            _ChannelToggle(
              channel: channel,
              // 값을 읽기 전에는 기본값을 보여준다. 토글이 사라졌다 나타나면
              // 설정이 초기화된 것처럼 읽힌다.
              enabled: settings.value?[channel] ?? channel.defaultOn,
              onChanged: (value) => _toggle(context, ref, channel, value),
            ),
          const SizedBox(height: 6),
          Text('"재촉" 계열은 기본으로 꺼 둬요. 필요할 때만 켜세요.', style: LqText.caption),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    LqNotificationChannel channel,
    bool enabled,
  ) async {
    try {
      await ref
          .read(notificationSettingsProvider.notifier)
          .toggle(channel, enabled);
    } catch (error) {
      // 저장에 실패하면 스위치가 되돌아간다. 이유를 말하지 않으면 탭이 씹힌 것으로
      // 읽힌다.
      if (context.mounted) showLqError(context, error);
    }
  }
}

class _ChannelToggle extends StatelessWidget {
  const _ChannelToggle({
    required this.channel,
    required this.enabled,
    required this.onChanged,
  });

  final LqNotificationChannel channel;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: enabled,
      label: channel.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!enabled),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LqSpacing.minTouchTarget,
          ),
          child: Row(
            children: [
              Expanded(child: Text(channel.label, style: LqText.bodySm)),
              _Switch(on: enabled),
            ],
          ),
        ),
      ),
    );
  }
}

/// 토글 — Material `Switch`는 라운드·테두리 언어가 맞지 않아 직접 그린다.
class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(2),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? LqColors.expFill : LqColors.disabledBg,
        borderRadius: LqShape.pillRadius,
        border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: LqColors.surfaceRaised,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: LqColors.ink, width: 1.6),
          ),
        ),
      ),
    );
  }
}
