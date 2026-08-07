import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 도감(S-13·S-14) 조회.
///
/// 서버 연결 없이 화면을 검토할 때만 [LqSampleData.orSample]의 표본을 사용한다.
/// 표본도 서버 카탈로그와 마찬가지로 실제 LOCATION 퀘스트 15개만 담는다.
class LifedexRepository {
  const LifedexRepository(this._dio);

  final Dio _dio;

  /// 전체 카테고리(`/lifedex/categories`)와 내 수집 현황(`/users/me/lifedex`)을
  /// 카테고리 id 기준으로 합쳐 하나의 뷰 모델로 만든다.
  Future<LifedexOverview> fetchOverview() =>
      LqSampleData.orSample(_fetchOverview, () => _sampleOverview);

  Future<LifedexOverview> _fetchOverview() => _guard(() async {
    final responses = await Future.wait([
      _dio.get<dynamic>('/lifedex/categories'),
      _dio.get<dynamic>('/users/me/lifedex'),
    ]);

    final all = _readCategories(responses[0].data);
    final mine = {
      for (final category in _readCategories(responses[1].data))
        category.id: category,
    };

    return LifedexOverview(
      categories: [
        for (final category in all)
          mine[category.id] == null
              ? category
              : category.mergeWith(mine[category.id]!),
      ],
    );
  });

  /// `GET /lifedex?categoryId=` — 카테고리 상세 항목(S-14).
  Future<List<LifedexItem>> fetchItems(int categoryId) => LqSampleData.orSample(
    () => _fetchItems(categoryId),
    () => [
      for (final item in _sampleItems)
        if (item.categoryId == categoryId) item,
    ],
  );

  Future<List<LifedexItem>> _fetchItems(int categoryId) => _guard(() async {
    final response = await _dio.get<dynamic>(
      '/lifedex',
      queryParameters: {'categoryId': categoryId},
    );
    final body = asMap(response.data);
    return asMapList(
      pick(body, ['items', 'content', 'lifedexItems']),
    ).map(LifedexItem.fromJson).toList();
  });

  List<LifedexCategory> _readCategories(Object? body) {
    final json = asMap(body);
    return asMapList(
      pick(json, ['categories', 'content', 'items']),
    ).map(LifedexCategory.fromJson).toList();
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  /// 실제 LOCATION 퀘스트 카탈로그를 그대로 축약한 검토용 수집 현황이다.
  /// 보유 여부만 화면 상태를 확인하기 위한 값이며 실제 사용자 데이터가 아니다.
  static const _sampleOverview = LifedexOverview(
    categories: [
      LifedexCategory(id: 1, name: '카페', totalCount: 1, ownedCount: 1),
      LifedexCategory(id: 2, name: '공원 · 산책로', totalCount: 5, ownedCount: 2),
      LifedexCategory(id: 3, name: '문화 · 전시', totalCount: 3, ownedCount: 1),
      LifedexCategory(id: 4, name: '시장 · 골목', totalCount: 2, ownedCount: 1),
      LifedexCategory(id: 5, name: '산 · 하천', totalCount: 2, ownedCount: 1),
      LifedexCategory(id: 6, name: '역사 · 명소', totalCount: 2, ownedCount: 0),
    ],
  );

  static const _sampleItems = [
    LifedexItem(
      id: 25,
      name: '성수동 카페거리',
      categoryId: 1,
      owned: true,
      description: '새로운 카페를 찾아 한 잔의 여유를 즐긴 기록',
    ),
    LifedexItem(
      id: 23,
      name: '반포한강공원',
      categoryId: 2,
      owned: true,
      description: '한강의 노을을 바라본 기록',
    ),
    LifedexItem(id: 24, name: '서울숲', categoryId: 2, owned: true),
    LifedexItem(id: 32, name: '경의선숲길', categoryId: 2, owned: false),
    LifedexItem(id: 41, name: '올림픽공원', categoryId: 2, owned: false),
    LifedexItem(id: 42, name: '서울식물원', categoryId: 2, owned: false),
    LifedexItem(id: 22, name: '서울도서관', categoryId: 3, owned: true),
    LifedexItem(id: 26, name: '서울시립미술관', categoryId: 3, owned: false),
    LifedexItem(id: 27, name: '국립중앙박물관', categoryId: 3, owned: false),
    LifedexItem(id: 29, name: '북촌한옥마을', categoryId: 4, owned: true),
    LifedexItem(id: 30, name: '광장시장', categoryId: 4, owned: false),
    LifedexItem(id: 21, name: '청계천', categoryId: 5, owned: true),
    LifedexItem(id: 40, name: '북한산 백운대', categoryId: 5, owned: false),
    LifedexItem(id: 28, name: '경복궁', categoryId: 6, owned: false),
    LifedexItem(id: 31, name: '남산서울타워', categoryId: 6, owned: false),
  ];
}
