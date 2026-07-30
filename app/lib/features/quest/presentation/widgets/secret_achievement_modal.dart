import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_pulse_ring.dart';
import 'package:life_quest/shared/widgets/lq_speck.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';

/// 메달 안쪽 채움 — 골드 계열이지만 배지 칸(`goldBg`)보다 한 톤 밝아 글자가 선다.
const _medallionFill = Color(0xFFF3DFA6);

/// 메달에 새길 글자.
///
/// 서버가 `symbol`을 주면 그대로 쓰고, 없으면 이름 첫 글자로 떨어진다. **이름이 빈
/// 문자열일 수 있다** — 비밀 업적의 마스킹을 빈 이름으로 표현하는 것이 이 앱의 규약이고
/// (`achievement_repository.dart`), 서버가 해금 응답에서 그 값을 그대로 흘려보낼 수 있다.
/// `characters.first`는 빈 문자열에서 던지므로 여기서 막지 않으면 완료 직후 모달이
/// 크래시하고, 완료는 다시 일으킬 수 없어 사용자가 복구할 방법이 없다.
String _medallionSymbol(CollectionEntry achievement) {
  final symbol = achievement.symbol;
  if (symbol != null && symbol.isNotEmpty) return symbol;
  return achievement.name.isEmpty ? '?' : achievement.name.characters.first;
}

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
    final openedAchievements = await showGeneralDialog<bool>(
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

    // "업적에서 보기"로 나갔으면 남은 해금은 띄우지 않는다. 그대로 이어 가면
    // 다음 모달이 방금 연 업적 화면 위에 겹치고, barrierDismissible이 false라
    // 사용자가 그 화면을 볼 수 없다.
    if (openedAchievements ?? false) return;
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
                      child: LqSpeck(
                        color: LqColors.gold,
                        angleDegrees: 20,
                        shape: BoxShape.rectangle,
                        duration: Duration(milliseconds: 2600),
                      ),
                    ),
                    const Positioned(
                      top: 12,
                      right: 2,
                      child: LqSpeck(
                        color: LqColors.accent,
                        size: 9,
                        duration: Duration(milliseconds: 3000),
                        delay: Duration(milliseconds: 400),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LqStamp(label: '비밀 업적 해금', angleDegrees: -4),
                        const SizedBox(height: 11),
                        _Medallion(symbol: _medallionSymbol(achievement)),
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
                            Navigator.of(context).pop(true);
                            context.push('/achievements');
                          },
                        ),
                        const SizedBox(height: 4),
                        _CloseLink(
                          onTap: () => Navigator.of(context).pop(false),
                        ),
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
