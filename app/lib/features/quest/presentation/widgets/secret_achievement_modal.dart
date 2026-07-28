import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_pulse_ring.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';

/// 메달 안쪽 채움 — 골드 계열이지만 배지 칸(`goldBg`)보다 한 톤 밝아 글자가 선다.
const _medallionFill = Color(0xFFF3DFA6);

/// S-17 비밀 업적 해금 알림 (화면맵 2e).
///
/// 완료 결과 위에 겹친다 — 해금은 사건이라 목록 한 줄로 알리면 놓친다.
/// 여러 건이 함께 해금되면 순서대로 하나씩 띄운다.
Future<void> showSecretAchievementModals(
  BuildContext context,
  List<CollectionEntry> achievements,
) async {
  for (final achievement in achievements) {
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '비밀 업적 해금',
      // 시안의 흐린 배경 — 뒤의 완료 결과가 비쳐야 무엇 위에 뜬 것인지 읽힌다.
      barrierColor: const Color(0x59443B2A),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, _) =>
          _SecretAchievementDialog(achievement: achievement),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          // 시안의 바운스 이징.
          curve: const Cubic(0.2, 0.8, 0.3, 1.2),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }
}

class _SecretAchievementDialog extends StatelessWidget {
  const _SecretAchievementDialog({required this.achievement});

  final CollectionEntry achievement;

  @override
  Widget build(BuildContext context) {
    final condition = achievement.condition;
    final exp = achievement.expReward;
    final title = achievement.titleReward;

    return Stack(
      children: [
        // 뒤 화면을 살짝 흐려 모달이 위에 얹힌 것으로 읽히게 한다.
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: LqColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: LqColors.ink,
                    width: LqShape.borderWidth,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x4D282012), offset: Offset(5, 6)),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: _Speck(
                        color: LqColors.gold,
                        size: 10,
                        angle: 20,
                        rounded: false,
                      ),
                    ),
                    const Positioned(
                      top: 12,
                      right: 2,
                      child: _Speck(color: LqColors.accent, size: 9),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LqStamp(
                          label: '비밀 업적 해금',
                          angleDegrees: -4,
                        ),
                        const SizedBox(height: 11),
                        _Medallion(
                          symbol:
                              achievement.symbol ??
                              achievement.name.characters.first,
                        ),
                        const SizedBox(height: 11),
                        Text(
                          achievement.name,
                          textAlign: TextAlign.center,
                          style: LqText.bigTitle.copyWith(fontSize: 23),
                        ),
                        // 조건 문장은 해금된 뒤에만 공개된다. 서버가 주지 않으면
                        // 지어내지 않고 비운다.
                        if (condition != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            condition,
                            textAlign: TextAlign.center,
                            style: LqText.bodySm.copyWith(fontSize: 15.5),
                          ),
                        ],
                        if (exp != null || title != null) ...[
                          const SizedBox(height: 11),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              if (exp != null)
                                LqRewardBadge(
                                  label: 'EXP $exp',
                                  background: LqColors.expBadge,
                                  foreground: LqColors.onDark,
                                  fontSize: 13,
                                ),
                              if (title != null)
                                LqRewardBadge(
                                  label: '칭호 · $title',
                                  background: LqColors.goldBg,
                                  foreground: LqColors.goldText,
                                  border: LqColors.goldBorder,
                                  fontSize: 13,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 15),
                        LqButton(
                          label: '업적에서 보기',
                          height: 46,
                          fontSize: 18,
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push('/achievements');
                          },
                        ),
                        const SizedBox(height: 4),
                        _CloseLink(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 해금 메달 — 펄스 링 + 살짝 찌그러진 원.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const LqPulseRing(
            minSize: 76,
            maxSize: 96,
            color: LqColors.goldBorder,
            duration: Duration(milliseconds: 2400),
          ),
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _medallionFill,
              // 완전한 원이 아니라 손으로 그린 듯 네 방향이 조금씩 다르다.
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(38, 38),
                topRight: Radius.elliptical(34, 38),
                bottomRight: Radius.elliptical(42, 38),
                bottomLeft: Radius.elliptical(38, 38),
              ),
              border: Border.all(
                color: LqColors.ink,
                width: LqShape.borderWidth,
              ),
            ),
            child: Text(
              symbol,
              style: LqText.displayTitle.copyWith(color: LqColors.goldText),
            ),
          ),
        ],
      ),
    );
  }
}

/// 떠다니는 장식 조각.
class _Speck extends StatefulWidget {
  const _Speck({
    required this.color,
    required this.size,
    this.angle = 0,
    this.rounded = true,
  });

  final Color color;
  final double size;
  final double angle;
  final bool rounded;

  @override
  State<_Speck> createState() => _SpeckState();
}

class _SpeckState extends State<_Speck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -9 * _controller.value),
          child: child,
        ),
        child: Transform.rotate(
          angle: widget.angle * math.pi / 180,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: widget.rounded ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.rounded
                  ? null
                  : BorderRadius.circular(3),
              border: Border.all(
                color: LqColors.ink,
                width: LqShape.borderWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseLink extends StatelessWidget {
  const _CloseLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '닫기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LqSpacing.minTouchTarget,
          ),
          alignment: Alignment.center,
          child: Text(
            '닫기',
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
