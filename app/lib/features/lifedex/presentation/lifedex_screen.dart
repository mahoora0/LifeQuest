import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';
import 'package:life_quest/shared/widgets/lq_progress_bar.dart';

/// 카테고리별 블롭 색 — 채도가 낮은 색을 순환해서 쓴다.
const _blobColors = <Color>[
  Color(0xFFCBD5AE),
  Color(0xFFE3C9A8),
  Color(0xFFC7D3DA),
  Color(0xFFD9C6E0),
  Color(0xFFE0C7C0),
  Color(0xFFC9D9C6),
];

Color _blobColorFor(int id) => _blobColors[id.abs() % _blobColors.length];

/// S-13 LifeDex 도감 / S-14 카테고리 상세.
class LifedexScreen extends ConsumerStatefulWidget {
  const LifedexScreen({super.key});

  @override
  ConsumerState<LifedexScreen> createState() => _LifedexScreenState();
}

class _LifedexScreenState extends ConsumerState<LifedexScreen> {
  /// null이면 카테고리 그리드(S-13), 값이 있으면 항목 그리드(S-14).
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(lifedexOverviewProvider);

    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 헤더는 조회 결과와 무관하게 항상 그린다. 본문과 함께 사라지면
            // 오류·준비 중 화면에서 돌아갈 길이 없어진다(탭 밖 라우트라 탭바도 없다).
            const _Header(),
            Expanded(
              child: LqAsyncView<LifedexOverview>(
                value: overview,
                isEmpty: (value) => value.isEmpty,
                emptyMessage: '아직 도감 카테고리가 없어요',
                notReadyMessage: '도감은 아직 준비 중이에요',
                notReadyHint: '서버가 열리면 수집한 항목이 여기 채워져요.',
                onRetry: () => ref.invalidate(lifedexOverviewProvider),
                data: (value) => _Body(
                  overview: value,
                  selectedCategoryId: _selectedCategoryId,
                  onSelectCategory: (id) =>
                      setState(() => _selectedCategoryId = id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 도감 헤더 — 뒤로 가기 · 제목 · 업적 바로가기.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LqSpacing.screen,
        8,
        LqSpacing.screen,
        0,
      ),
      child: Row(
        children: [
          // 탭이 아니라 마이페이지에서 push로 열리는 화면이라 돌아갈 길이 필요하다.
          LqIconButton(
            icon: Icons.arrow_back,
            semanticLabel: '뒤로 가기',
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LqColors.surfaceTint,
              borderRadius: LqShape.tileRadius,
              border: Border.all(
                color: LqColors.ink,
                width: LqShape.borderWidth,
              ),
            ),
            child: const LqImage(LqAssets.iconBackpack, width: 20),
          ),
          const SizedBox(width: 8),
          Text('LifeDex', style: LqText.screenTitle),
          const Spacer(),
          LqIconButton(
            icon: Icons.emoji_events_outlined,
            semanticLabel: '업적',
            onTap: () => context.push('/achievements'),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.overview,
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  final LifedexOverview overview;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelectCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = overview.categories;
    final selectedIndex = selectedCategoryId == null
        ? 0
        : categories.indexWhere((c) => c.id == selectedCategoryId) + 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LqSpacing.screen,
        LqSpacing.gap,
        LqSpacing.screen,
        24,
      ),
      children: [
        _CollectionRate(overview: overview),
        const SizedBox(height: LqSpacing.gap),
        LqChipRow(
          padding: EdgeInsets.zero,
          labels: ['전체', for (final category in categories) category.name],
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          onSelected: (index) =>
              onSelectCategory(index == 0 ? null : categories[index - 1].id),
        ),
        const SizedBox(height: 4),
        if (selectedCategoryId == null)
          _CategoryGrid(
            categories: categories,
            onTap: (category) => onSelectCategory(category.id),
          )
        else
          _ItemGrid(categoryId: selectedCategoryId!),
        const SizedBox(height: LqSpacing.gap),
        LqCard(
          background: LqColors.surfaceCard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const LqImage(LqAssets.charMap, width: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Text('새 경험을 수집하면 도감이 하나씩 채워져요!', style: LqText.bodySm),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionRate extends StatelessWidget {
  const _CollectionRate({required this.overview});

  final LifedexOverview overview;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('수집률', style: LqText.label),
              const SizedBox(width: 8),
              Text(
                '${overview.percent}%',
                style: LqText.levelNumber.copyWith(
                  fontSize: 22,
                  color: LqColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${overview.ownedCount}/${overview.totalCount}',
                style: LqText.bodySm,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LqProgressBar(value: overview.ownedCount, max: overview.totalCount),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.onTap});

  final List<LifedexCategory> categories;
  final void Function(LifedexCategory) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.84,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _DexTile(
          label: category.name,
          caption: '${category.ownedCount}/${category.totalCount}',
          color: _blobColorFor(category.id),
          locked: category.isLocked,
          onTap: () => onTap(category),
        );
      },
    );
  }
}

class _ItemGrid extends ConsumerWidget {
  const _ItemGrid({required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(lifedexItemsProvider(categoryId));

    return SizedBox(
      // 항목 그리드는 로딩·빈·오류 상태에서도 일정한 높이를 차지한다.
      height: (items.value?.isNotEmpty ?? false) ? null : 240,
      child: LqAsyncView<List<LifedexItem>>(
        value: items,
        isEmpty: (value) => value.isEmpty,
        emptyMessage: '이 카테고리에는 아직 항목이 없어요',
        notReadyMessage: '항목 목록은 아직 준비 중이에요',
        onRetry: () => ref.invalidate(lifedexItemsProvider(categoryId)),
        data: (value) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.84,
          ),
          itemCount: value.length,
          itemBuilder: (context, index) {
            final item = value[index];
            return _DexTile(
              label: item.owned ? item.name : '?',
              caption: item.owned ? '수집' : '잠김',
              color: _blobColorFor(item.id),
              locked: !item.owned,
            );
          },
        ),
      ),
    );
  }
}

/// 도감 카드 — 유기적 원형 블롭 + 이름 + 카운트. 잠김은 점선 변형.
class _DexTile extends StatelessWidget {
  const _DexTile({
    required this.label,
    required this.caption,
    required this.color,
    required this.locked,
    this.onTap,
  });

  final String label;
  final String caption;
  final Color color;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      radius: LqShape.tileRadius,
      locked: locked,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: locked ? LqColors.lockedTile : color,
              border: Border.all(
                color: locked ? LqColors.borderMuted : LqColors.ink,
                width: LqShape.borderWidth,
              ),
              // 정원이 아니라 살짝 찌그러진 유기적 블롭.
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(22, 18),
                topRight: Radius.elliptical(18, 22),
                bottomRight: Radius.elliptical(22, 18),
                bottomLeft: Radius.elliptical(18, 22),
              ),
            ),
            child: locked
                ? Text(
                    '?',
                    style: LqText.cardTitle.copyWith(color: LqColors.textMuted),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: LqText.caption.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: locked ? LqColors.textMuted : LqColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(caption, style: LqText.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
