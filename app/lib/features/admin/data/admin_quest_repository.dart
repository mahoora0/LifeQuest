import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/admin/data/admin_quest.dart';
import 'package:life_quest/shared/data/json_reader.dart';

class AdminQuestRepository {
  const AdminQuestRepository(this._dio);

  final Dio _dio;

  Future<List<AdminQuest>> fetchQuests() => _guard(() async {
    final response = await _dio.get<dynamic>(
      '/admin/quests',
      queryParameters: const {'page': 0, 'size': 100},
    );
    return asMapList(
      asMap(response.data)['content'],
    ).map(AdminQuest.fromJson).toList();
  });

  Future<AdminQuest> create(AdminQuestDraft draft) => _guard(() async {
    final response = await _dio.post<dynamic>(
      '/admin/quests',
      data: draft.toJson(),
    );
    return AdminQuest.fromJson(asMap(response.data));
  });

  Future<AdminQuest> update(int id, AdminQuestDraft draft) => _guard(() async {
    final response = await _dio.patch<dynamic>(
      '/admin/quests/$id',
      data: draft.toJson(),
    );
    return AdminQuest.fromJson(asMap(response.data));
  });

  Future<void> deactivate(int id) => _guard(() async {
    await _dio.delete<dynamic>('/admin/quests/$id');
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
