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
import 'package:life_quest/shared/widgets/lq_icon.dart';
import 'package:life_quest/shared/widgets/lq_image.dart';

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
                emptyMessage: '아직 연결된 위치 퀘스트 도감이 없어요',
                notReadyMessage: '위치 퀘스트 도감은 아직 준비 중이에요',
                notReadyHint: '준비가 끝나면 다녀온 장소가 여기 채워져요.',
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
          Text('도감', style: LqText.screenTitle),
          // 업적으로 건너가는 트로피 버튼은 뺐다. 도감과 업적은 형제 화면이 아니라
          // 둘 다 마이페이지 "나의 기록" 아래에 있어, 서로를 여는 문이 계층을 흐린다.
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
        const _LocationQuestGuide(),
        const SizedBox(height: LqSpacing.gap),
        _CollectionSummary(overview: overview),
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
          _ItemGrid(
            categoryId: selectedCategoryId!,
            // 항목이 자기 모티프를 갖지 않을 때 물러날 자리. 카테고리를 고른
            // 뒤에야 그리는 화면이라 여기서 이미 알고 있다.
            categoryIconKey: categories
                .where((c) => c.id == selectedCategoryId)
                .map((c) => c.iconKey)
                .firstOrNull,
          ),
      ],
    );
  }
}

/// 무엇을 하면 도감이 채워지는지 알려 주는 안내 카드.
///
/// 수집 범위는 주기가 아니라 <b>위치 퀘스트인가</b>로 정해진다
/// (docs/05-business-rules.md §6-1). 일간·주간 어느 쪽이든 다녀온 장소는 남는다.
class _LocationQuestGuide extends StatelessWidget {
  const _LocationQuestGuide();

  @override
  Widget build(BuildContext context) {
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const LqImage(LqAssets.charMap, width: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('위치 퀘스트 전용', style: LqText.label),
                const SizedBox(height: 4),
                Text('지도에 표시된 곳에 다녀오면 그 장소가 도감에 남아요.', style: LqText.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  const _CollectionSummary({required this.overview});

  final LifedexOverview overview;

  @override
  Widget build(BuildContext context) {
    return LqCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('수집한 경험', style: LqText.label),
          const Spacer(),
          Text(
            '${overview.ownedCount}개',
            style: LqText.levelNumber.copyWith(
              fontSize: 22,
              color: LqColors.primary,
            ),
          ),
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
          iconKey: category.iconKey,
          locked: category.isLocked,
          onTap: () => onTap(category),
        );
      },
    );
  }
}

class _ItemGrid extends ConsumerWidget {
  const _ItemGrid({required this.categoryId, this.categoryIconKey});

  final int categoryId;

  /// 항목에 모티프가 지정되지 않았을 때 대신 그릴 카테고리 모티프.
  final String? categoryIconKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(lifedexItemsProvider(categoryId));

    return ConstrainedBox(
      // 항목 그리드는 로딩·빈·오류 상태에서도 일정한 높이를 차지한다.
      // 홈의 오늘의 퀘스트 카드와 같은 이유로 고정이 아닌 최소 높이다:
      // 오류 상태(캐릭터 + 문구 + "다시 시도" 버튼 + 패딩)가 240을 넘겨 잘린다.
      constraints: BoxConstraints(
        minHeight: (items.value?.isNotEmpty ?? false) ? 0 : 240,
      ),
      child: LqAsyncView<List<LifedexItem>>(
        value: items,
        isEmpty: (value) => value.isEmpty,
        emptyMessage: '이 카테고리에 연결된 위치 퀘스트가 아직 없어요',
        notReadyMessage: '위치 퀘스트 도감 목록은 아직 준비 중이에요',
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
              caption: item.owned ? '수집' : '위치 퀘스트로 해금',
              color: _blobColorFor(item.id),
              iconKey: item.iconKey ?? categoryIconKey,
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
    this.iconKey,
    this.onTap,
  });

  final String label;
  final String caption;
  final Color color;

  /// 장소 모티프 키. 모르는 키·null이면 아이콘 없이 블롭만 그린다.
  final String? iconKey;
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
            // 미획득은 모티프를 감춘다 — 무엇을 모았는지가 아니라 무엇이
            // 남았는지만 보여야 다음에 갈 곳을 찾아 나서게 된다.
            child: locked
                ? Text(
                    '?',
                    style: LqText.cardTitle.copyWith(color: LqColors.textMuted),
                  )
                : switch (LqLifedexIcons.pathOf(iconKey)) {
                    final String asset => LqIcon(asset, size: 22),
                    null => null,
                  },
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
