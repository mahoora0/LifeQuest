import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/data/friend_repository.dart';

void main() {
  test('내 친구 코드를 서버에서 조회한다', () async {
    final dio = _dio((options) {
      expect(options.path, '/users/me/friend-code');
      return {'friendCode': 'LQ-0000002A'};
    });

    final code = await FriendRepository(dio).fetchMyCode();

    expect(code, 'LQ-0000002A');
  });

  test('친구 코드를 공통 검색어 query로 전달한다', () async {
    String? searchQuery;
    final dio = _dio((options) {
      if (options.path == '/users/search') {
        searchQuery = options.queryParameters['query'] as String?;
      }
      return {'content': <Object>[]};
    });

    await FriendRepository(dio).searchAdventurers('LQ-0000002A');

    expect(searchQuery, 'LQ-0000002A');
  });

  test('친구 목록에도 내 친구 코드를 함께 담는다', () async {
    final dio = _dio((options) {
      if (options.path == '/users/me/friend-code') {
        return {'friendCode': 'LQ-0000002A'};
      }
      return {
        'content': [
          {'userId': 7, 'nickname': '친구', 'level': 3},
        ],
      };
    });

    final list = await FriendRepository(dio).fetchFriends();

    expect(list.myCode, 'LQ-0000002A');
    expect(list.friends.single.nickname, '친구');
  });

  test('전체 레벨 랭킹 경로와 기준을 전달한다', () async {
    String? path;
    String? type;
    final dio = _dio((options) {
      path = options.path;
      type = options.queryParameters['type'] as String?;
      return {'content': <Object>[]};
    });

    await FriendRepository(
      dio,
    ).fetchWeeklyRanking(scope: RankingScope.global, type: RankingType.level);

    expect(path, '/rankings/global');
    expect(type, 'LEVEL');
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
