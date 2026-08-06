import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/admin/data/admin_quest.dart';
import 'package:life_quest/features/admin/data/admin_quest_repository.dart';

void main() {
  test('관리자 퀘스트 목록을 조회한다', () async {
    final dio = _dio((options) {
      expect(options.path, '/admin/quests');
      expect(options.queryParameters['size'], 100);
      return {
        'content': [
          {
            'id': 3,
            'title': '아침 산책',
            'grade': 'NORMAL',
            'cadence': 'DAILY',
            'completionType': 'SELF_REPORT',
            'expReward': 10,
            'active': true,
          },
        ],
      };
    });

    final quests = await AdminQuestRepository(dio).fetchQuests();

    expect(quests.single.title, '아침 산책');
  });

  test('관리자 퀘스트 등록 요청을 전달한다', () async {
    Object? body;
    final dio = _dio((options) {
      body = options.data;
      return {
        'id': 4,
        ...Map<String, dynamic>.from(options.data as Map),
      };
    });

    await AdminQuestRepository(dio).create(
      const AdminQuestDraft(
        title: '물 마시기',
        grade: 'NORMAL',
        cadence: 'DAILY',
        completionType: 'SELF_REPORT',
        expReward: 10,
        active: true,
      ),
    );

    expect((body as Map)['title'], '물 마시기');
  });
}

Dio _dio(Map<String, dynamic> Function(RequestOptions) responseFor) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: responseFor(options),
        ),
      ),
    ),
  );
  return dio;
}
