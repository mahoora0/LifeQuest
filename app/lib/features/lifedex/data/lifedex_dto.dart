import 'package:life_quest/shared/data/json_reader.dart';

/// 도감 카테고리 + 내 수집 현황(두 API를 합쳐서 만든다).
class LifedexCategory {
  const LifedexCategory({
    required this.id,
    required this.name,
    required this.totalCount,
    required this.ownedCount,
    this.iconKey,
  });

  final int id;
  final String name;
  final int totalCount;
  final int ownedCount;

  /// 카테고리 모티프 키(`LqLifedexIcons`). 항목이 자기 키를 갖지 않을 때
  /// 항목 타일이 이 키로 물러난다.
  final String? iconKey;

  bool get isLocked => ownedCount == 0;

  factory LifedexCategory.fromJson(Map<String, dynamic> json) =>
      LifedexCategory(
        id: asInt(pick(json, ['id', 'categoryId'])) ?? 0,
        name: asString(pick(json, ['name', 'categoryName'])) ?? '카테고리',
        totalCount:
            asInt(pick(json, ['totalCount', 'totalItemCount', 'total'])) ?? 0,
        ownedCount:
            asInt(pick(json, ['ownedCount', 'collectedCount', 'owned'])) ?? 0,
        iconKey: asString(pick(json, ['iconKey', 'icon_key'])),
      );

  LifedexCategory mergeWith(LifedexCategory other) => LifedexCategory(
    id: id,
    name: name.isNotEmpty ? name : other.name,
    totalCount: totalCount != 0 ? totalCount : other.totalCount,
    ownedCount: other.ownedCount != 0 ? other.ownedCount : ownedCount,
    iconKey: iconKey ?? other.iconKey,
  );
}

/// 도감 항목 1건(S-14 카테고리 상세).
class LifedexItem {
  const LifedexItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.owned,
    this.description,
    this.iconKey,
  });

  final int id;
  final String name;
  final int categoryId;
  final bool owned;
  final String? description;

  /// 장소 모티프 키(`LqLifedexIcons`). null이면 카테고리 모티프로 물러난다.
  final String? iconKey;

  factory LifedexItem.fromJson(Map<String, dynamic> json) => LifedexItem(
    id: asInt(pick(json, ['id', 'itemId'])) ?? 0,
    name: asString(pick(json, ['name', 'itemName'])) ?? '항목',
    categoryId: asInt(pick(json, ['categoryId', 'category_id'])) ?? 0,
    owned: asBool(pick(json, ['owned', 'collected', 'isCollected'])),
    description: asString(json['description']),
    iconKey: asString(pick(json, ['iconKey', 'icon_key'])),
  );
}

/// LifeDex 화면이 쓰는 통합 뷰 모델.
class LifedexOverview {
  const LifedexOverview({required this.categories});

  final List<LifedexCategory> categories;

  int get totalCount =>
      categories.fold(0, (sum, category) => sum + category.totalCount);
  int get ownedCount =>
      categories.fold(0, (sum, category) => sum + category.ownedCount);
  bool get isEmpty => categories.isEmpty;
}
