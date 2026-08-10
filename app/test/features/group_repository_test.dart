import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/group/data/group_repository.dart';

void main() {
  test('그룹 멤버가 50명을 넘으면 모든 페이지를 합쳐 반환한다', () async {
    final requestedPages = <int>[];
    final dio = _pagedDio((options, page) {
      expect(options.path, '/groups/1/members');
      requestedPages.add(page);
      return _page(
        page: page,
        totalPages: 2,
        content: page == 0
            ? [for (var id = 1; id <= 50; id++) _member(id)]
            : [_member(51)],
      );
    });

    final members = await GroupRepository(dio).members(1);

    expect(
      members.map((member) => member.userId),
      List.generate(51, (i) => i + 1),
    );
    expect(requestedPages, [0, 1]);
  });

  test('가입 요청도 첫 페이지에서 끝내지 않는다', () async {
    final dio = _pagedDio((options, page) {
      expect(options.path, '/groups/1/join-requests');
      return _page(
        page: page,
        totalPages: 2,
        content: page == 0 ? [_member(1)] : [_member(51)],
      );
    });

    final requests = await GroupRepository(dio).joinRequests(1);

    expect(requests.map((member) => member.userId), [1, 51]);
  });

  test('그룹 퀘스트의 모든 페이지를 순서대로 합친다', () async {
    final requestedPages = <int>[];
    final dio = _pagedDio((options, page) {
      expect(options.path, '/groups/1/quests');
      expect(options.queryParameters['scope'], 'UPCOMING');
      requestedPages.add(page);
      return _page(page: page, totalPages: 3, content: [_quest(page + 1)]);
    });

    final quests = await GroupRepository(dio).quests(1, upcoming: true);

    expect(quests.map((quest) => quest.id), [1, 2, 3]);
    expect(requestedPages, [0, 1, 2]);
  });
}

Dio _pagedDio(
  Map<String, dynamic> Function(RequestOptions options, int page) responseFor,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final page = options.queryParameters['page'] as int;
        expect(options.queryParameters['size'], 50);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: responseFor(options, page),
          ),
        );
      },
    ),
  );
  return dio;
}

Map<String, dynamic> _page({
  required int page,
  required int totalPages,
  required List<Map<String, dynamic>> content,
}) => {
  'content': content,
  'page': page,
  'size': 50,
  'totalElements': content.length,
  'totalPages': totalPages,
};

Map<String, dynamic> _member(int id) => {
  'memberId': id,
  'groupId': 1,
  'groupName': '테스트 그룹',
  'userId': id,
  'nickname': '멤버$id',
  'role': 'MEMBER',
  'status': 'ACTIVE',
};

Map<String, dynamic> _quest(int id) => {
  'id': id,
  'groupId': 1,
  'createdByUserId': 1,
  'creatorNickname': '그룹장',
  'title': '퀘스트$id',
  'description': '설명',
  'placeName': '장소',
  'scheduledAt': '2026-08-11T12:00:00',
  'status': 'PUBLISHED',
};
