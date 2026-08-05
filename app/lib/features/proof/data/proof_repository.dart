import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';

class ProofRepository {
  const ProofRepository(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<ProofFeedPage> feed({
    required ProofFeedTab tab,
    int? cursor,
    int size = 10,
  }) => _guard(() async {
    final response = await _dio.get<dynamic>(
      '/quest-proofs',
      queryParameters: {'tab': tab.wire, 'cursor': ?cursor, 'size': size},
    );
    return ProofFeedPage.fromJson(asMap(response.data));
  });

  Future<ProofPost> detail(int postId) => _guard(() async {
    final response = await _dio.get<dynamic>('/quest-proofs/$postId');
    return ProofPost.fromJson(asMap(response.data));
  });

  Future<List<ProofCandidate>> candidates() => _guard(() async {
    final response = await _dio.get<dynamic>('/quest-proofs/candidates');
    return asMapList(response.data).map(ProofCandidate.fromJson).toList();
  });

  /// 사진은 `photos` 파트로 여러 장 보낸다. 퀘스트는 `completionId`가 결정하므로
  /// 따로 싣지 않는다.
  Future<ProofPost> create({
    required int completionId,
    required List<String> photoPaths,
    String? content,
  }) => _guard(() async {
    final form = FormData();
    form.fields.add(MapEntry('completionId', '$completionId'));
    if (content != null && content.trim().isNotEmpty) {
      form.fields.add(MapEntry('content', content.trim()));
    }
    for (final path in photoPaths) {
      final fileName = path.split(RegExp(r'[/\\]')).last;
      form.files.add(
        MapEntry(
          'photos',
          await MultipartFile.fromFile(path, filename: fileName),
        ),
      );
    }

    final response = await _dio.post<dynamic>('/quest-proofs', data: form);
    return ProofPost.fromJson(asMap(response.data));
  });

  Future<ProofVoteResult> vote(int postId, ProofVoteChoice choice) =>
      _guard(() async {
        final response = await _dio.post<dynamic>(
          '/quest-proofs/$postId/votes',
          data: {'choice': choice.wire},
        );
        return ProofVoteResult.fromJson(asMap(response.data));
      });

  Future<List<ProofComment>> comments(int postId) => _guard(() async {
    final response = await _dio.get<dynamic>('/quest-proofs/$postId/comments');
    return asMapList(response.data).map(ProofComment.fromJson).toList();
  });

  Future<ProofComment> addComment(int postId, String content) =>
      _guard(() async {
        final response = await _dio.post<dynamic>(
          '/quest-proofs/$postId/comments',
          data: {'content': content},
        );
        return ProofComment.fromJson(asMap(response.data));
      });

  Future<void> delete(int postId) =>
      _guard(() async => _dio.delete<dynamic>('/quest-proofs/$postId'));
}
