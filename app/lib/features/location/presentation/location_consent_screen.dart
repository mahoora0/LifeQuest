import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/location/application/location_consent_controller.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_speck.dart';

/// 1단계 · 위치 권한 전면 안내 (화면맵 2a).
///
/// 가입·로그인 직후 첫 실행에 한 번 띄운다. 권한을 왜 쓰는지 먼저 설명해 OS 팝업의
/// 거절률을 낮춘다 — 설명 없이 팝업부터 띄우면 영구 거부로 굳어 되돌릴 방법이
/// 설정 앱뿐이 된다.
class LocationConsentScreen extends ConsumerWidget {
  const LocationConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: Stack(
        children: [
          const Positioned(
            top: 120,
            left: 32,
            child: LqSpeck(
              color: LqColors.gold,
              angleDegrees: 20,
              shape: BoxShape.rectangle,
            ),
          ),
          const Positioned(
            top: 190,
            right: 36,
            child: LqSpeck(
              color: LqColors.gem,
              duration: Duration(milliseconds: 3200),
              delay: Duration(milliseconds: 500),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          '원정을 시작하기 전에\n지도를 펼쳐 둘까요?',
                          textAlign: TextAlign.center,
                          style: LqText.bigTitle.copyWith(height: 1.25),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: LqImage(LqAssets.charMap, width: 168),
                        ),
                        const SizedBox(height: 16),
                        const _UsesCard(),
                        const SizedBox(height: 16),
                        // 무엇에 쓰는지와 함께 무엇을 하지 않는지도 밝힌다.
                        const _PrivacyNote(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  LqButton(
                    label: '지도를 펼치고 시작하기',
                    fontSize: 19,
                    onPressed: () => _allow(context, ref),
                  ),
                  _LaterLink(onTap: () => _defer(context, ref)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _allow(BuildContext context, WidgetRef ref) async {
    await ref.read(locationConsentProvider.notifier).request();
    // 허용이든 거절이든 이 화면은 닫는다. 남겨 두면 OS 팝업을 거절한 사람이
    // 같은 버튼을 다시 누르게 되고, 두 번째부터는 팝업이 뜨지 않아 헛돈다.
    if (context.mounted) _close(context);
  }

  Future<void> _defer(BuildContext context, WidgetRef ref) async {
    await ref.read(locationConsentProvider.notifier).defer();
    if (context.mounted) _close(context);
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

/// 두 가지 쓰임 — 무엇에 쓰는지가 분명해야 허용을 판단할 수 있다.
class _UsesCard extends StatelessWidget {
  const _UsesCard();

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const _UseRow(
            icon: LqAssets.iconFlag,
            iconWidth: 16,
            tint: LqColors.locBg,
            title: '현장 퀘스트 인증',
            description: '목표 반경에 들어왔는지 판정해요',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: LqDashedDivider(color: LqColors.divider),
          ),
          const _UseRow(
            icon: LqAssets.iconMap,
            iconWidth: 22,
            tint: Color(0xFFDCE8C6),
            title: '주변 원정지 탐색',
            description: '가까운 퀘스트를 지도에 띄워요',
          ),
        ],
      ),
    );
  }
}

class _UseRow extends StatelessWidget {
  const _UseRow({
    required this.icon,
    required this.iconWidth,
    required this.tint,
    required this.title,
    required this.description,
  });

  final String icon;
  final double iconWidth;
  final Color tint;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(13),
              bottomRight: Radius.circular(10),
              bottomLeft: Radius.circular(13),
            ),
            border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
          ),
          child: LqImage(icon, width: iconWidth),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title\n',
                  style: LqText.bodySm.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: LqText.bodySm.copyWith(fontSize: 15.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return LqCard(
      locked: true,
      radius: LqShape.rowRadius,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: '위치는 '),
            TextSpan(
              text: '인증하는 순간에만',
              style: LqText.label.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(text: ' 확인하고 이동 경로는 저장하지 않아요. 나중에 설정에서 다시 끌 수 있어요.'),
          ],
          style: LqText.label.copyWith(fontSize: 14.5, height: 1.4),
        ),
      ),
    );
  }
}

class _LaterLink extends StatelessWidget {
  const _LaterLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '나중에 할게요',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LqSpacing.minTouchTarget,
          ),
          alignment: Alignment.center,
          child: Text(
            '나중에 할게요',
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
