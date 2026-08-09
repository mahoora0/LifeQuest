import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';

/// 도감(S-13·S-14) 조회.
class LifedexRepository {
  const LifedexRepository(this._dio);

  final Dio _dio;

  /// 전체 카테고리(`/lifedex/categories`)와 내 수집 현황(`/users/me/lifedex`)을
  /// 카테고리 id 기준으로 합쳐 하나의 뷰 모델로 만든다.
  Future<LifedexOverview> fetchOverview() => _fetchOverview();

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
  Future<List<LifedexItem>> fetchItems(int categoryId) =>
      _fetchItems(categoryId);

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
}
