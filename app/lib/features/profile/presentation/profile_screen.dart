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

/// 무효화만 하면 동기적으로 끝나 스피너가 즉시 사라진다.
/// 실제 재조회가 끝날 때까지 기다려야 당김-새로고침이 의미를 갖는다.
Future<void> _refresh(WidgetRef ref) async {
  ref
    ..invalidate(myProfileProvider)
    ..invalidate(levelStatusProvider)
    ..invalidate(questHistoryProvider)
    ..invalidate(lifedexOverviewProvider)
    ..invalidate(achievementOverviewProvider)
    ..invalidate(titleCollectionProvider);

  await Future.wait([
    _settle(ref.read(myProfileProvider.future)),
    _settle(ref.read(levelStatusProvider.future)),
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
                const _ExpCard(),
                // ① 재화 2칸은 서버에 재화가 없어 v1에서 노출하지 않는다.
                const SizedBox(height: LqSpacing.gap),
                const _GrowthRecordCard(),
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

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(levelStatusProvider);
    final character = profile.selectedCharacter;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 158),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: character == null
                ? '나의 캐릭터, 꾸미기'
                : '나의 캐릭터 ${character.name}, 꾸미기',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/profile/character'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.all(2),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: LqColors.surfaceTint,
                      borderRadius: LqShape.cardRadius,
                      border: Border.all(
                        color: LqColors.ink,
                        width: LqShape.borderWidth,
                      ),
                    ),
                    child: Transform.scale(
                      scale: 1.08,
                      child: LqImage(
                        character == null
                            ? LqAssets.charFront
                            : LqAssets.characterWithAccessory(
                                character.code,
                                profile.selectedAccessory?.code,
                              ),
                        width: 128,
                        height: 128,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '캐릭터 꾸미기',
                    style: LqText.caption.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderProfilePhoto(
                      imageUrl: profile.profileImageUrl,
                      onTap: () => context.push('/profile/edit'),
                    ),
                    const SizedBox(width: 10),
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
                                  style: LqText.sectionTitle.copyWith(
                                    fontSize: 25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => context.push('/profile/edit'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
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
                                      fontSize: 14,
                                      color: LqColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            profile.representativeTitle ?? '대표 칭호 없음',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LqText.bodySm.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: profile.representativeTitle == null
                                  ? LqColors.textMuted
                                  : LqColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Text(
                    level.value == null
                        ? 'Lv. —'
                        : 'Lv. ${level.requireValue.level}',
                    style: LqText.levelNumber.copyWith(fontSize: 29),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderProfilePhoto extends StatelessWidget {
  const _HeaderProfilePhoto({required this.imageUrl, required this.onTap});

  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.resolveMediaUrl(imageUrl);
    const fallback = Icon(
      Icons.person_rounded,
      size: 29,
      color: LqColors.textMuted,
    );

    return Semantics(
      button: true,
      label: '프로필 사진 변경',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: LqColors.surfaceRaised,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LqColors.ink,
                    width: LqShape.borderWidth,
                  ),
                ),
                child: resolved.isEmpty
                    ? fallback
                    : Image.network(
                        resolved,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: LqColors.surfaceRaised,
                    shape: BoxShape.circle,
                    border: Border.all(color: LqColors.ink, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 11,
                    color: LqColors.primary,
                  ),
                ),
              ),
            ],
          ),
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
      // 레벨 · 보상(S-05)의 유일한 진입점. "나의 기록"에 행을 더하는 대신 값이
      // 이미 보이는 자리를 누르게 하는 쪽이 어디로 가는지 예측하기 쉽다.
      onTap: () => context.push('/rewards'),
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
              // 누를 수 있다는 표식. 없으면 카드가 눌리는지 알 수 없다.
              Text(
                '›',
                style: LqText.cardTitle.copyWith(color: LqColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LqProgressBar(
            value: status?.currentLevelExp ?? 0,
            max: status?.nextLevelRequiredExp ?? 0,
          ),
          // 남은 EXP는 진행바 아래 제 줄을 쓴다. 첫 줄에 같이 두면 시안 폭
          // 360에서 자리가 54px 모자라 말줄임되고, 레벨이 오를수록 더 나빠진다.
          if (status != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '다음 레벨까지 ${status.remainingExp}',
                style: LqText.caption,
              ),
            ),
          ],
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

    return LqCard(
      background: LqColors.surfaceCard,
      header: '나의 기록',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecordRow(
            leading: const _RecordTile(asset: LqAssets.book, width: 42),
            label: '도감',
            caption: _caption(lifedex, (value) => '${value.ownedCount}개 수집'),
            onTap: () => context.push('/lifedex'),
          ),
          const LqDashedDivider(),
          _RecordRow(
            leading: const _RecordTile(asset: LqAssets.trophyCup, width: 42),
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
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LqColors.tileFill,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
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
          // "내 그룹" 행은 하단 그룹 탭으로 옮겼다. 같은 화면으로 가는 입구를
          // 둘 두면 탭에서 열었을 때와 push로 열었을 때 뒤로가기가 달라진다.
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
