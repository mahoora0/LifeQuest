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
import 'package:life_quest/shared/widgets/lq_map.dart';
import 'package:life_quest/shared/widgets/lq_pulse_ring.dart';

/// S-11 지역 지도.
///
/// 주변 위치 퀘스트를 실지도 위의 마커로 보여준다. 지도 키가 없으면([LqMap])
/// 시안의 탐험 캔버스가 그대로 그려지므로, 키 없이 실행해도 화면이 비지 않는다.
///
/// 마커를 탭하면 곧바로 상세로 넘어가지 않고 하단 카드가 그 퀘스트로 바뀐다.
/// 지도 위에서는 마커가 잘못 눌리기 쉬워, 화면 전환을 한 단계 뒤로 미룬다.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  /// 사용자가 고른 마커. 없으면 하단 카드는 가장 가까운 퀘스트를 보여준다.
  int? _selectedDailyQuestId;

  /// 카메라 되돌리기 신호. 값이 바뀔 때마다 [LqMap]이 시야를 다시 맞춘다.
  int _focusToken = 0;

  @override
  Widget build(BuildContext context) {
    final nearby = ref.watch(nearbyQuestsProvider);
    final result = nearby.hasValue ? nearby.requireValue : null;
    final quests = result?.quests ?? const <DailyQuest>[];
    final selected = _selectedOf(quests);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          // ListView와 달리 Column은 자식을 가로로 늘리지 않아, 두지 않으면 하단
          // 요약 카드가 글자 길이만큼만 넓어진다.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LqHeader(title: '지역 지도', showBack: false),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  LqSpacing.screen,
                  4,
                  LqSpacing.screen,
                  0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      LqMap(
                        height: constraints.maxHeight,
                        fallback: _ExplorationCanvas(
                          height: constraints.maxHeight,
                        ),
                        markers: _markersOf(quests),
                        focusToken: _focusToken,
                        myLocation: result == null
                            ? null
                            : LqLatLng(
                                result.origin.latitude,
                                result.origin.longitude,
                              ),
                        onTap: () =>
                            setState(() => _selectedDailyQuestId = null),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _RecenterButton(
                          onPressed: () {
                            setState(() {
                              _selectedDailyQuestId = null;
                              _focusToken++;
                            });
                            ref.invalidate(nearbyQuestsProvider);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LqSpacing.screen,
                LqSpacing.gap,
                LqSpacing.screen,
                LqSpacing.gap,
              ),
              child: _NearbySummary(nearby: nearby, selected: selected),
            ),
          ],
        ),
      ),
    );
  }

  DailyQuest? _selectedOf(List<DailyQuest> quests) {
    final id = _selectedDailyQuestId;
    if (id == null) return null;
    for (final quest in quests) {
      if (quest.dailyQuestId == id) return quest;
    }
    // 재조회로 목록이 바뀌어 선택한 퀘스트가 사라진 경우.
    return null;
  }

  List<LqMapMarker> _markersOf(List<DailyQuest> quests) {
    final markers = <LqMapMarker>[];
    for (final dailyQuest in quests) {
      final quest = dailyQuest.quest;
      if (!quest.hasCoordinates) continue;
      markers.add(
        LqMapMarker(
          id: 'quest-${dailyQuest.dailyQuestId}',
          position: LqLatLng(quest.latitude!, quest.longitude!),
          label: quest.placeName ?? quest.title,
          color: _gradeColor(quest.grade),
          selected: dailyQuest.dailyQuestId == _selectedDailyQuestId,
          onTap: () =>
              setState(() => _selectedDailyQuestId = dailyQuest.dailyQuestId),
        ),
      );
    }
    return markers;
  }
}

/// 등급 색. 목록·인증 화면과 같은 값을 써서 지도가 다른 언어를 쓰지 않게 한다.
Color _gradeColor(String? grade) => switch (grade) {
  'RARE' => LqColors.gradeRare,
  'EPIC' => LqColors.gradeEpic,
  'LEGENDARY' => LqColors.gradeLegendary,
  _ => LqColors.gradeNormal,
};

/// 시야를 되돌리는 버튼.
///
/// 내 위치와 주변 퀘스트가 함께 보이도록 카메라를 다시 맞추고, 주변 목록을 다시
/// 조회한다. **새 GPS fix를 강제하지는 않는다** — 조회는 캐시된 마지막 위치를 먼저
/// 쓰고([nearbyQuestsProvider]), 새 fix를 잡는 경로가 지도 탭 ANR의 원인이었다.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: LqSpacing.minTouchTarget,
        height: LqSpacing.minTouchTarget,
        decoration: BoxDecoration(
          color: LqColors.surfaceRaised,
          shape: BoxShape.circle,
          border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
        ),
        child: const Icon(
          Icons.my_location,
          size: 20,
          color: LqColors.textPrimary,
        ),
      ),
    );
  }
}

/// 유기적 블롭 지역 4개 · 점선 경로 · 현재 위치 캐릭터 · 펄스 링.
///
/// 지도 키가 없을 때의 대체 화면이다. 블롭 위치·라벨은 모두 장식이며 실제 좌표를
/// 매핑하지 않는다 — 지도가 있는 것처럼 보이되 없는 정보를 지어내지는 않는다.
class _ExplorationCanvas extends StatelessWidget {
  const _ExplorationCanvas({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      height: height,
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

/// 하단 요약 카드.
///
/// 마커를 고르면 그 퀘스트를, 고르지 않았으면 가장 가까운 퀘스트를 보여준다.
class _NearbySummary extends ConsumerWidget {
  const _NearbySummary({required this.nearby, this.selected});

  final AsyncValue<NearbyQuests> nearby;

  /// 지도에서 고른 퀘스트. `null`이면 최근접을 쓴다.
  final DailyQuest? selected;

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
    final nearest = selected ?? result.nearest;

    return LqCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      onTap: nearest == null ? null : () => _openDetail(context, nearest),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected == null
                ? '근처 퀘스트 ${result.quests.length}개'
                : selected!.quest.placeName ?? '선택한 퀘스트',
            style: LqText.cardTitle,
          ),
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
