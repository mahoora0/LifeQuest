import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/core/location/geo_math.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_dashed.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_pulse_ring.dart';
import 'package:life_quest/shared/widgets/lq_reward_badge.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';
import 'package:life_quest/shared/widgets/lq_status_banner.dart';

/// 위치 인증 상태 머신 (07 명세 §5-8).
enum _VerifyStage {
  /// 위치 권한이 거부됨.
  permissionDenied,

  /// 기기 GPS가 꺼져 있음.
  serviceDisabled,

  /// 위치 스트림 대기 중.
  locating,

  /// 퀘스트에 좌표가 없어 판정할 수 없음.
  missingTarget,

  /// accuracy가 min(radius_m, 100)보다 큼 — 자동 재시도.
  lowAccuracy,

  /// 반경 밖.
  outOfRadius,

  /// 반경 안 — 인증 가능.
  inRadius,
}

/// 디버그 빌드 전용 좌표 시뮬레이터 시나리오.
enum _DebugScenario {
  real('실제 GPS'),
  inside('반경 안'),
  outside('반경 밖'),
  denied('권한 거부');

  const _DebugScenario(this.label);

  final String label;
}

/// S-10 GPS 위치 인증.
class QuestVerifyScreen extends ConsumerStatefulWidget {
  const QuestVerifyScreen({
    super.key,
    required this.dailyQuestId,
    required this.quest,
  });

  final int dailyQuestId;
  final Quest quest;

  @override
  ConsumerState<QuestVerifyScreen> createState() => _QuestVerifyScreenState();
}

class _QuestVerifyScreenState extends ConsumerState<QuestVerifyScreen> {
  StreamSubscription<Position>? _subscription;

  _VerifyStage _stage = _VerifyStage.locating;
  Position? _position;
  double? _distanceM;
  bool _submitting = false;

  /// 서버가 되돌려준 거절 사유(거리 값 포함) — 배너에 그대로 보여준다.
  String? _serverMessage;

  _DebugScenario _scenario = _DebugScenario.real;

  LocationService get _service => ref.read(locationServiceProvider);
  int get _radiusM => widget.quest.effectiveRadiusM;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (!widget.quest.hasCoordinates) {
      setState(() => _stage = _VerifyStage.missingTarget);
      return;
    }

    await _subscription?.cancel();
    _subscription = null;
    setState(() {
      _stage = _VerifyStage.locating;
      _serverMessage = null;
    });

    if (!await _service.isServiceEnabled()) {
      if (!mounted) return;
      setState(() => _stage = _VerifyStage.serviceDisabled);
      return;
    }

    var permission = await _service.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _service.requestPermission();
    }
    if (!mounted) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _stage = _VerifyStage.permissionDenied);
      return;
    }

    _subscription = _service.watchPosition().listen(
      _onPosition,
      onError: (Object _) {
        if (mounted) setState(() => _stage = _VerifyStage.locating);
      },
    );
  }

  void _onPosition(Position position) {
    if (!mounted) return;

    final quest = widget.quest;
    final distance = haversineDistanceM(
      lat1: position.latitude,
      lng1: position.longitude,
      lat2: quest.latitude!,
      lng2: quest.longitude!,
    );

    setState(() {
      _position = position;
      _distanceM = distance;
      _serverMessage = null;
      if (position.accuracy > accuracyLimitM(_radiusM)) {
        // 스트림이 계속 흐르므로 자동으로 재시도되는 셈이다.
        _stage = _VerifyStage.lowAccuracy;
      } else if (distance > _radiusM) {
        _stage = _VerifyStage.outOfRadius;
      } else {
        _stage = _VerifyStage.inRadius;
      }
    });
  }

  // --- 디버그 전용 좌표 시뮬레이터 (운영 빌드에서는 노출되지 않는다) ---
  Future<void> _applyScenario(_DebugScenario scenario) async {
    setState(() => _scenario = scenario);

    if (scenario == _DebugScenario.real) {
      await _start();
      return;
    }

    await _subscription?.cancel();
    _subscription = null;

    if (scenario == _DebugScenario.denied) {
      setState(() {
        _stage = _VerifyStage.permissionDenied;
        _position = null;
        _distanceM = null;
      });
      return;
    }

    final quest = widget.quest;
    if (!quest.hasCoordinates) {
      setState(() => _stage = _VerifyStage.missingTarget);
      return;
    }

    // 위도 1도 ≈ 111km. 반경의 3배만큼 북쪽으로 밀어 반경 밖을 만든다.
    final offsetDegrees = scenario == _DebugScenario.inside
        ? 0.0
        : (_radiusM * 3) / 111000;

    _onPosition(
      Position(
        latitude: quest.latitude! + offsetDegrees,
        longitude: quest.longitude!,
        timestamp: DateTime.now(),
        accuracy: 8,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }

  Future<void> _submit() async {
    final position = _position;
    if (position == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(todayQuestsProvider.notifier)
          .complete(
            widget.dailyQuestId,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          );
      if (!mounted) return;
      await _showSuccessDialog(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      // 최종 판정은 서버다. 서버가 거절하면 해당 상태 배너로 되돌린다.
      switch (error.code) {
        case 'OUT_OF_RADIUS':
          setState(() {
            _stage = _VerifyStage.outOfRadius;
            _serverMessage = lqErrorMessage(error);
          });
        case 'LOCATION_ACCURACY_TOO_LOW':
          setState(() {
            _stage = _VerifyStage.lowAccuracy;
            _serverMessage = lqErrorMessage(error);
          });
        default:
          showLqError(context, error);
      }
    } catch (error) {
      if (!mounted) return;
      showLqError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog(QuestCompletionResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: LqColors.ink.withValues(alpha: 0.45),
      builder: (dialogContext) => _SuccessDialog(
        result: result,
        onConfirm: () => Navigator.of(dialogContext).pop(),
      ),
    );
    if (!mounted) return;
    // 인증 화면을 결과 화면으로 교체한다.
    context.pushReplacement('/quests/result', extra: result);
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;

    return Scaffold(
      backgroundColor: LqColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '위치 인증'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  LqSpacing.screen,
                  4,
                  LqSpacing.screen,
                  16,
                ),
                children: [
                  Center(child: LqRewardBadge.location()),
                  const SizedBox(height: 8),
                  Text(
                    quest.title,
                    textAlign: TextAlign.center,
                    style: LqText.bigTitle,
                  ),
                  if (quest.placeName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      quest.placeName!,
                      textAlign: TextAlign.center,
                      style: LqText.caption,
                    ),
                  ],
                  const SizedBox(height: LqSpacing.gap),
                  _RadarCard(
                    radiusM: _radiusM,
                    inRadius: _stage == _VerifyStage.inRadius,
                    locating:
                        _stage == _VerifyStage.locating ||
                        _stage == _VerifyStage.lowAccuracy,
                  ),
                  const SizedBox(height: LqSpacing.gap),
                  LqStatusBanner(
                    tone: _bannerTone,
                    message: _serverMessage ?? _bannerMessage,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _distanceLabel,
                    textAlign: TextAlign.center,
                    style: LqText.caption,
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: LqSpacing.gap),
                    _DebugSimulator(
                      scenario: _scenario,
                      onChanged: _applyScenario,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LqSpacing.screen,
                0,
                LqSpacing.screen,
                16,
              ),
              child: _buildCta(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta() {
    return switch (_stage) {
      _VerifyStage.permissionDenied => LqButton(
        label: '위치 권한 허용하기',
        onPressed: () async {
          final permission = await _service.requestPermission();
          if (permission == LocationPermission.deniedForever) {
            await _service.openAppSettings();
          }
          await _start();
        },
      ),
      _VerifyStage.serviceDisabled => LqButton(
        label: '위치 설정 열기',
        onPressed: () async {
          await _service.openLocationSettings();
          await _start();
        },
      ),
      _VerifyStage.missingTarget => const LqButton(label: '위치 정보를 확인할 수 없어요'),
      _VerifyStage.locating => const LqButton(label: '내 위치를 찾는 중…'),
      _VerifyStage.lowAccuracy => const LqButton(label: '정확도를 기다리는 중…'),
      _VerifyStage.outOfRadius => const LqButton(label: '반경 안에서 인증할 수 있어요'),
      _VerifyStage.inRadius => LqButton(
        label: '현재 위치로 인증하기',
        busy: _submitting,
        onPressed: _submit,
      ),
    };
  }

  LqBannerTone get _bannerTone => switch (_stage) {
    _VerifyStage.inRadius => LqBannerTone.success,
    _VerifyStage.outOfRadius || _VerifyStage.lowAccuracy => LqBannerTone.warn,
    _VerifyStage.permissionDenied ||
    _VerifyStage.serviceDisabled ||
    _VerifyStage.missingTarget => LqBannerTone.danger,
    _VerifyStage.locating => LqBannerTone.neutral,
  };

  String get _bannerMessage => switch (_stage) {
    _VerifyStage.permissionDenied => '위치 권한이 꺼져 있어요',
    _VerifyStage.serviceDisabled => 'GPS가 꺼져 있어요',
    _VerifyStage.missingTarget => '이 퀘스트에는 인증 좌표가 없어요',
    _VerifyStage.locating => '내 위치를 찾는 중…',
    _VerifyStage.lowAccuracy => '위치 정확도가 낮아요 — 잠시 후 다시',
    _VerifyStage.outOfRadius => '아직 반경 밖이에요 — 조금 더 가까이!',
    _VerifyStage.inRadius => '반경 안이에요! 인증할 수 있어요',
  };

  String get _distanceLabel {
    final distance = _distanceM;
    final accuracy = _position?.accuracy;
    if (distance == null || accuracy == null) {
      return '인증 반경 ${_radiusM}m';
    }
    return '목표까지 ${distance.round()}m · GPS 정확도 ±${accuracy.round()}m';
  }
}

/// 레이더 카드 — 점선 동심원 2개 · 중앙 깃발 · 펄스 링 · 내 위치 캐릭터.
class _RadarCard extends StatelessWidget {
  const _RadarCard({
    required this.radiusM,
    required this.inRadius,
    required this.locating,
  });

  final int radiusM;
  final bool inRadius;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.panel,
      height: 238,
      padding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(206, 206),
            painter: const LqDashedCirclePainter(),
          ),
          CustomPaint(
            size: const Size(136, 136),
            painter: const LqDashedCirclePainter(dashCount: 24),
          ),
          const LqPulseRing(),
          const LqImage(LqAssets.iconFlag, width: 34),

          // 내 위치 — 반경 안/밖에 따라 500ms 동안 이동한다.
          AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            alignment: inRadius
                ? const Alignment(0.34, 0.30)
                : const Alignment(0.82, 0.72),
            child: Opacity(
              opacity: locating ? 0.45 : 1,
              child: const LqImage(LqAssets.charFront, width: 46),
            ),
          ),

          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: LqColors.card,
                borderRadius: LqShape.pillRadius,
                border: Border.all(
                  color: LqColors.ink,
                  width: LqShape.borderWidth,
                ),
              ),
              child: Text('인증 반경 ${radiusM}m', style: LqText.caption),
            ),
          ),
        ],
      ),
    );
  }
}

/// 디버그 빌드 한정 좌표 시뮬레이터 (`05-business-rules.md` §3-4).
///
/// 실기기 없이 반경 안/밖·권한 거부 흐름을 확인하기 위한 도구이며
/// `kDebugMode` 가드로 운영 빌드에서는 트리에 올라가지 않는다.
class _DebugSimulator extends StatelessWidget {
  const _DebugSimulator({required this.scenario, required this.onChanged});

  final _DebugScenario scenario;
  final ValueChanged<_DebugScenario> onChanged;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      locked: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('디버그 · 좌표 시뮬레이터', style: LqText.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in _DebugScenario.values)
                GestureDetector(
                  onTap: () => onChanged(value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: value == scenario
                          ? LqColors.primary
                          : LqColors.card,
                      borderRadius: LqShape.pillRadius,
                      border: Border.all(
                        color: value == scenario
                            ? LqColors.ink
                            : LqColors.borderMuted,
                        width: 1.6,
                      ),
                    ),
                    child: Text(
                      value.label,
                      style: LqText.badge.copyWith(
                        fontSize: 12,
                        color: value == scenario
                            ? LqColors.onDark
                            : LqColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 인증 성공 모달 — 확인하면 완료 결과 화면으로 넘어간다.
class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.result, required this.onConfirm});

  final QuestCompletionResult result;
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
            const LqImage(LqAssets.charMap, width: 116),
            const SizedBox(height: 12),
            Text('인증 성공!', style: LqText.sectionTitle),
            const SizedBox(height: 8),
            if (result.location?.distanceM != null)
              Text(
                '목표에서 ${result.location!.distanceM!.round()}m 지점에서 인증했어요',
                textAlign: TextAlign.center,
                style: LqText.caption,
              ),
            const SizedBox(height: 12),
            LqRewardBadge(
              label: 'EXP ${result.growth.expGained}',
              background: LqColors.expBadge,
              foreground: LqColors.onDark,
              fontSize: 14,
            ),
            const SizedBox(height: 16),
            LqButton(label: '확인', onPressed: onConfirm),
          ],
        ),
      ),
    );
  }
}
