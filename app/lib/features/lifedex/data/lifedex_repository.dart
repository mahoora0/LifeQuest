import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 도감(S-13·S-14) 조회.
///
/// ⚠ 백엔드에 lifedex 컨트롤러가 아직 없어 세 경로 모두 404다. 화면을 검토할 수
/// 있도록 [LqSampleData.orSample]이 **`LQ_SAMPLES`를 켰고 컨트롤러가 없을 때만** 표본으로
/// 떨어진다. 서버가 그 경로를 열면 실제 응답이 오므로 표본은 저절로 물러난다.
///
// TODO(server): GET /lifedex/categories · GET /users/me/lifedex · GET /lifedex
//  개설 시 아래 표본 상수(_sampleCategories·_sampleItems)를 지운다. 호출 코드는
//  이미 실경로를 가리키고 있어 그대로 둔다.
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

  /// 시안(`Life Quest 초안` LifeDex 화면)의 수집률 42%를 재현하는 표본이다.
  /// 실제 사용자 데이터가 아니며 디버그 빌드에서만 쓰인다.
  static const _sampleOverview = LifedexOverview(
    categories: [
      LifedexCategory(id: 1, name: '카페', totalCount: 24, ownedCount: 12),
      LifedexCategory(id: 2, name: '공원 · 산책로', totalCount: 20, ownedCount: 11),
      LifedexCategory(id: 3, name: '문화 · 전시', totalCount: 18, ownedCount: 7),
      LifedexCategory(id: 4, name: '시장 · 골목', totalCount: 22, ownedCount: 8),
      LifedexCategory(id: 5, name: '산 · 하천', totalCount: 16, ownedCount: 4),
    ],
  );

  static const _sampleItems = [
    LifedexItem(
      id: 101,
      name: '골목 끝 로스터리',
      categoryId: 1,
      owned: true,
      description: '처음으로 도장을 찍은 카페예요.',
    ),
    LifedexItem(id: 102, name: '북촌 한옥 찻집', categoryId: 1, owned: true),
    LifedexItem(id: 103, name: '연남동 브런치 카페', categoryId: 1, owned: false),
    LifedexItem(
      id: 201,
      name: '경의선숲길',
      categoryId: 2,
      owned: true,
      description: '길게 이어진 숲길을 끝까지 걸었어요.',
    ),
    LifedexItem(id: 202, name: '서울숲', categoryId: 2, owned: true),
    LifedexItem(id: 203, name: '올림픽공원', categoryId: 2, owned: false),
    LifedexItem(id: 301, name: '시립 미술관', categoryId: 3, owned: true),
    LifedexItem(id: 302, name: '국립중앙박물관', categoryId: 3, owned: false),
    LifedexItem(id: 401, name: '광장시장', categoryId: 4, owned: true),
    LifedexItem(id: 402, name: '망원시장', categoryId: 4, owned: false),
    LifedexItem(id: 501, name: '북한산 백운대', categoryId: 5, owned: false),
    LifedexItem(id: 502, name: '청계천 물길', categoryId: 5, owned: true),
  ];
}
