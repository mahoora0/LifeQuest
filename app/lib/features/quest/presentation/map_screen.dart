import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/core/location/geo_math.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/quest_route_args.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_pulse_ring.dart';

/// S-11 지역 지도.
///
/// 지도 SDK가 아직 선정되지 않아(07 명세 §6-⑥) 지도 영역은 시안의
/// 탐험 테마 일러스트 placeholder를 유지한다. 실데이터를 쓰는 것은
/// 하단 요약 카드뿐이며, GPS 인증 로직은 지도 제공자에 의존하지 않는다.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(nearbyQuestsProvider);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LqHeader(title: '지역 지도', showBack: false),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  LqSpacing.screen,
                  4,
                  LqSpacing.screen,
                  24,
                ),
                children: [
                  const _ExplorationCanvas(),
                  const SizedBox(height: LqSpacing.gap),
                  _NearbySummary(nearby: nearby),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 유기적 블롭 지역 4개 · 점선 경로 · 현재 위치 캐릭터 · 펄스 링.
///
/// 이 캔버스의 블롭 위치·라벨은 모두 장식이며 실제 좌표를 매핑하지 않는다.
/// 지도 SDK 선정 후 이 위젯만 교체하면 된다.
class _ExplorationCanvas extends StatelessWidget {
  const _ExplorationCanvas();

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      height: 300,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: LqShape.cardRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: const _DashedTrailPainter()),
            ),
            const Positioned(
              left: 26,
              top: 34,
              child: _RegionBlob(label: '숲길 구역', size: 74),
            ),
            const Positioned(
              right: 24,
              top: 66,
              child: _RegionBlob(label: '골목 상권', size: 62),
            ),
            const Positioned(
              left: 40,
              bottom: 54,
              child: _RegionBlob(label: '강변 산책로', size: 66),
            ),
            const Positioned(
              right: 34,
              bottom: 92,
              child: _RegionBlob(label: '언덕 전망대', size: 58),
            ),
            const Align(
              alignment: Alignment(0, 0.12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  LqPulseRing(minSize: 40, maxSize: 118),
                  LqImage(LqAssets.charFront, width: 52),
                ],
              ),
            ),
            Positioned(
              left: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: LqColors.surfaceRaised,
                  borderRadius: LqShape.pillRadius,
                  border: Border.all(color: LqColors.ink, width: 1.6),
                ),
                child: Text('내 위치 주변', style: LqText.caption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionBlob extends StatelessWidget {
  const _RegionBlob({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size * 0.82,
          decoration: BoxDecoration(
            color: LqColors.lockedTile,
            border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
            borderRadius: BorderRadius.only(
              topLeft: Radius.elliptical(size * 0.6, size * 0.4),
              topRight: Radius.elliptical(size * 0.4, size * 0.5),
              bottomRight: Radius.elliptical(size * 0.55, size * 0.42),
              bottomLeft: Radius.elliptical(size * 0.45, size * 0.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: LqText.caption.copyWith(fontSize: 12)),
      ],
    );
  }
}

/// 지역들을 잇는 점선 경로(장식).
class _DashedTrailPainter extends CustomPainter {
  const _DashedTrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LqColors.borderMuted
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.26)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.14,
        size.width * 0.76,
        size.height * 0.3,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.52,
        size.width * 0.24,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.84,
        size.width * 0.78,
        size.height * 0.68,
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 7, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedTrailPainter oldDelegate) => false;
}

/// 하단 요약 카드 — 이 화면에서 유일하게 실데이터를 쓰는 부분.
class _NearbySummary extends ConsumerWidget {
  const _NearbySummary({required this.nearby});

  final AsyncValue<NearbyQuests> nearby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (nearby.hasError && !nearby.isLoading) {
      return _LocationErrorCard(
        message: lqErrorMessage(nearby.error!),
        onOpenSettings: () async {
          await ref.read(locationServiceProvider).openLocationSettings();
          ref.invalidate(nearbyQuestsProvider);
        },
        onRetry: () => ref.invalidate(nearbyQuestsProvider),
      );
    }

    if (!nearby.hasValue) {
      return const LqCard(
        height: 96,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: LqColors.primary,
            ),
          ),
        ),
      );
    }

    final result = nearby.requireValue;
    final nearest = result.nearest;

    return LqCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      onTap: nearest == null ? null : () => _openDetail(context, nearest),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('근처 퀘스트 ${result.quests.length}개', style: LqText.cardTitle),
          const SizedBox(height: 6),
          if (nearest == null)
            Text('주변에 위치 퀘스트가 없어요', style: LqText.caption)
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    nearest.quest.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LqText.bodySm,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _distanceLabel(result, nearest),
                  style: LqText.caption.copyWith(color: LqColors.primary),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: LqColors.textMuted,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 서버가 거리를 주지 않으면 현재 위치로 직접 계산한다.
  String _distanceLabel(NearbyQuests result, DailyQuest nearest) {
    final distance =
        nearest.distanceM ??
        (nearest.quest.hasCoordinates
            ? haversineDistanceM(
                lat1: result.origin.latitude,
                lng1: result.origin.longitude,
                lat2: nearest.quest.latitude!,
                lng2: nearest.quest.longitude!,
              )
            : null);
    return distance == null ? '' : '${distance.round()}m';
  }

  void _openDetail(BuildContext context, DailyQuest dailyQuest) {
    context.push(
      '/quests/${dailyQuest.questId}',
      extra: QuestDetailArgs(
        dailyQuestId: dailyQuest.dailyQuestId,
        status: dailyQuest.status,
      ),
    );
  }
}

class _LocationErrorCard extends StatelessWidget {
  const _LocationErrorCard({
    required this.message,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: LqText.bodySm.copyWith(color: LqColors.textSecondary),
          ),
          const SizedBox(height: 12),
          LqButton(label: '위치 설정 열기', onPressed: onOpenSettings),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRetry,
            child: SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  '다시 시도',
                  style: LqText.caption.copyWith(color: LqColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
