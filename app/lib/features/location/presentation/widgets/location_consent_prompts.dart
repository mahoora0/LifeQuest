import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/location/application/location_consent_controller.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';

/// 2단계 · 홈 배너 (화면맵 2b).
///
/// 1단계에서 넘긴 사람에게만 보이고, 권한을 허용하면 함께 걷힌다.
/// 배너는 상시 남지만 시트는 위치 퀘스트를 눌렀을 때만 올라온다 —
/// 홈에 들어올 때마다 시트가 막으면 재촉으로 읽힌다.
class LocationConsentBanner extends ConsumerWidget {
  const LocationConsentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(locationConsentProvider).value;
    if (stage == null || !stage.needsBanner) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: LqSpacing.gap),
      child: LqCard(
        radius: LqShape.rowRadius,
        background: LqColors.warnBg,
        // 배너는 상태 표시라 테두리 색을 글자 색과 맞춘다(LqStatusBanner와 같은 언어).
        borderColor: LqColors.warnText,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        onTap: () => showLocationPermissionSheet(context, ref),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LqColors.warnText,
                  width: LqShape.borderWidth,
                ),
              ),
              child: Text(
                '!',
                style: LqText.badge.copyWith(
                  fontSize: 16,
                  color: LqColors.warnText,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '지도가 아직 접혀 있어요\n'),
                    TextSpan(
                      text: '현장 퀘스트를 인증하려면 위치가 필요해요',
                      style: LqText.caption.copyWith(
                        fontWeight: FontWeight.w400,
                        color: LqColors.warnText,
                      ),
                    ),
                  ],
                  style: LqText.bodySm.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: LqColors.warnText,
                  ),
                ),
              ),
            ),
            Text(
              '›',
              style: LqText.cardTitle.copyWith(color: LqColors.warnText),
            ),
          ],
        ),
      ),
    );
  }
}

/// 위치 퀘스트를 열기 전에 한 번 설명한다 (2b).
///
/// 시트를 닫으면 허용 여부와 무관하게 원래 가려던 곳으로 이어 간다 —
/// 인증 전에 반경·장소를 보게 하는 것이 상세 화면의 몫이라 여기서 막으면
/// 사용자가 무엇을 허용하는지 모른 채 판단하게 된다.
Future<void> ensureLocationConsent(
  BuildContext context,
  WidgetRef ref, {
  required bool isLocationQuest,
}) async {
  if (!isLocationQuest) return;

  final stage = ref.read(locationConsentProvider).value;
  if (stage == null || !stage.needsSheet) return;

  await showLocationPermissionSheet(context, ref);
}

/// 2단계 · 바텀 시트.
///
/// 권한을 허용했으면 `true`. 호출부는 이 값과 무관하게 원래 가려던 곳으로
/// 이어 가도 된다 — 시트는 막는 문이 아니라 한 번의 설명이다.
Future<bool> showLocationPermissionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final granted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x59443B2A),
    builder: (sheetContext) => const _PermissionSheet(),
  );
  return granted ?? false;
}

class _PermissionSheet extends ConsumerWidget {
  const _PermissionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 영구 거부면 같은 버튼으로 다시 요청해도 팝업이 뜨지 않는다.
    // 설정으로 보내지 않으면 사용자가 헛돌게 된다.
    final blocked =
        ref.watch(locationConsentProvider).value ==
        LocationConsentStage.blocked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      decoration: const BoxDecoration(
        color: LqColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(color: LqColors.ink, width: LqShape.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: const BoxDecoration(
                color: LqColors.borderMuted,
                borderRadius: LqShape.pillRadius,
              ),
            ),
            const SizedBox(height: 12),
            const LqImage(LqAssets.charMap, width: 112),
            const SizedBox(height: 12),
            Text(
              blocked ? '위치 권한이 꺼져 있어요' : '현장 인증에 지도가 필요해요',
              textAlign: TextAlign.center,
              style: LqText.sectionTitle.copyWith(fontSize: 22, height: 1.25),
            ),
            const SizedBox(height: 12),
            Text(
              blocked
                  ? '설정에서 위치 권한을 켜면\n현장 퀘스트를 인증할 수 있어요.'
                  : '인증하는 순간에만 위치를 확인하고\n이동 경로는 저장하지 않아요.',
              textAlign: TextAlign.center,
              style: LqText.bodySm.copyWith(fontSize: 15.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            LqButton(
              label: blocked ? '설정에서 켜기' : '위치 권한 허용하기',
              fontSize: 19,
              onPressed: () => _act(context, ref, blocked: blocked),
            ),
            _SkipLink(onTap: () => _skip(context, ref)),
          ],
        ),
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref, {
    required bool blocked,
  }) async {
    final controller = ref.read(locationConsentProvider.notifier);
    if (blocked) {
      await controller.openSettings();
      if (context.mounted) Navigator.of(context).pop(false);
      return;
    }

    final granted = await controller.request();
    if (context.mounted) Navigator.of(context).pop(granted);
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    await ref.read(locationConsentProvider.notifier).defer();
    if (context.mounted) Navigator.of(context).pop(false);
  }
}

class _SkipLink extends StatelessWidget {
  const _SkipLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '지금은 넘어가기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LqSpacing.minTouchTarget,
          ),
          alignment: Alignment.center,
          child: Text(
            '지금은 넘어가기',
            style: LqText.bodySm.copyWith(
              color: LqColors.textSecondary,
              decoration: TextDecoration.underline,
              decorationColor: LqColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
