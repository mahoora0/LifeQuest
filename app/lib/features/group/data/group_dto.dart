import 'package:life_quest/shared/data/json_reader.dart';

enum GroupVisibility { public, private }

enum GroupRole { owner, member }

enum GroupMembershipStatus {
  invited,
  pendingApproval,
  active,
  rejected,
  left,
  removed,
}

enum GroupStatus { active, archived }

enum GroupQuestStatus { published, cancelled }

T _enum<T>(String? raw, Map<String, T> values, T fallback) =>
    values[raw] ?? fallback;

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.activeMemberCount,
    required this.maxMembers,
    required this.joinable,
    required this.status,
    this.myRole,
    this.myMembershipStatus,
  });
  final int id;
  final String name;
  final String description;
  final int activeMemberCount;
  final int maxMembers;
  final bool joinable;
  final GroupRole? myRole;
  final GroupMembershipStatus? myMembershipStatus;
  final GroupStatus status;
  bool get isOwner => myRole == GroupRole.owner;
  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
    id: asInt(pick(j, ['groupId', 'id'])) ?? 0,
    name: asString(j['name']) ?? '그룹',
    description: asString(j['description']) ?? '',
    activeMemberCount: asInt(j['activeMemberCount']) ?? 0,
    maxMembers: asInt(j['maxMembers']) ?? 0,
    joinable: asBool(j['joinable']),
    myRole: _role(asString(j['myRole'])),
    myMembershipStatus: _membership(asString(j['myMembershipStatus'])),
    status: _enum(asString(j['status']), {
      'ACTIVE': GroupStatus.active,
      'ARCHIVED': GroupStatus.archived,
    }, GroupStatus.active),
  );
}

class GroupMember {
  const GroupMember({
    required this.memberId,
    required this.groupId,
    required this.groupName,
    required this.userId,
    required this.nickname,
    required this.role,
    required this.status,
    this.expiresAt,
    this.joinedAt,
  });
  final int memberId, groupId, userId;
  final String groupName, nickname;
  final GroupRole role;
  final GroupMembershipStatus status;
  final DateTime? expiresAt, joinedAt;
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
    memberId: asInt(j['memberId']) ?? 0,
    groupId: asInt(j['groupId']) ?? 0,
    groupName: asString(j['groupName']) ?? '그룹',
    userId: asInt(j['userId']) ?? 0,
    nickname: asString(j['nickname']) ?? '모험가',
    role: _role(asString(j['role'])) ?? GroupRole.member,
    status:
        _membership(asString(j['status'])) ?? GroupMembershipStatus.rejected,
    expiresAt: DateTime.tryParse(asString(j['expiresAt']) ?? ''),
    joinedAt: DateTime.tryParse(asString(j['joinedAt']) ?? ''),
  );
}

class GroupQuest {
  const GroupQuest({
    required this.id,
    required this.groupId,
    required this.createdByUserId,
    required this.creatorNickname,
    required this.title,
    required this.description,
    required this.placeName,
    required this.scheduledAt,
    required this.status,
  });
  final int id, groupId, createdByUserId;
  final String creatorNickname, title, description, placeName;
  final DateTime scheduledAt;
  final GroupQuestStatus status;
  factory GroupQuest.fromJson(Map<String, dynamic> j) => GroupQuest(
    id: asInt(j['id']) ?? 0,
    groupId: asInt(j['groupId']) ?? 0,
    createdByUserId: asInt(j['createdByUserId']) ?? 0,
    creatorNickname: asString(j['creatorNickname']) ?? '모험가',
    title: asString(j['title']) ?? '그룹 퀘스트',
    description: asString(j['description']) ?? '',
    placeName: asString(j['placeName']) ?? '',
    scheduledAt:
        DateTime.tryParse(asString(j['scheduledAt']) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    status: _enum(asString(j['status']), {
      'PUBLISHED': GroupQuestStatus.published,
      'CANCELLED': GroupQuestStatus.cancelled,
    }, GroupQuestStatus.published),
  );
}

class GroupDetail {
  const GroupDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.visibility,
    required this.maxMembers,
    required this.activeMemberCount,
    required this.status,
    required this.ownerUserId,
    required this.ownerNickname,
    required this.joinable,
    required this.members,
    required this.recentQuests,
    this.myRole,
    this.myMembershipStatus,
  });
  final int id, maxMembers, activeMemberCount, ownerUserId;
  final String name, description, ownerNickname;
  final GroupVisibility visibility;
  final GroupStatus status;
  final bool joinable;
  final GroupRole? myRole;
  final GroupMembershipStatus? myMembershipStatus;
  final List<GroupMember> members;
  final List<GroupQuest> recentQuests;
  bool get isOwner => myRole == GroupRole.owner;
  bool get isActiveMember => myMembershipStatus == GroupMembershipStatus.active;
  bool get archived => status == GroupStatus.archived;
  factory GroupDetail.fromJson(Object? body) {
    final j = asMap(body);
    return GroupDetail(
      id: asInt(j['id']) ?? 0,
      name: asString(j['name']) ?? '그룹',
      description: asString(j['description']) ?? '',
      visibility: _enum(asString(j['visibility']), {
        'PUBLIC': GroupVisibility.public,
        'PRIVATE': GroupVisibility.private,
      }, GroupVisibility.public),
      maxMembers: asInt(j['maxMembers']) ?? 0,
      activeMemberCount: asInt(j['activeMemberCount']) ?? 0,
      status: _enum(asString(j['status']), {
        'ACTIVE': GroupStatus.active,
        'ARCHIVED': GroupStatus.archived,
      }, GroupStatus.active),
      ownerUserId: asInt(j['ownerUserId']) ?? 0,
      ownerNickname: asString(j['ownerNickname']) ?? '모험가',
      joinable: asBool(j['joinable']),
      myRole: _role(asString(j['myRole'])),
      myMembershipStatus: _membership(asString(j['myMembershipStatus'])),
      members: asMapList(j['members']).map(GroupMember.fromJson).toList(),
      recentQuests: asMapList(
        j['recentQuests'],
      ).map(GroupQuest.fromJson).toList(),
    );
  }
}

class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.senderUserId,
    required this.senderNickname,
    required this.content,
    required this.mine,
    required this.createdAt,
  });
  final int id, senderUserId;
  final String senderNickname, content;
  final bool mine;
  final DateTime createdAt;
  factory GroupMessage.fromJson(Map<String, dynamic> j) => GroupMessage(
    id: asInt(j['id']) ?? 0,
    senderUserId: asInt(j['senderUserId']) ?? 0,
    senderNickname: asString(j['senderNickname']) ?? '모험가',
    content: asString(j['content']) ?? '',
    mine: asBool(j['mine']),
    createdAt:
        DateTime.tryParse(asString(j['createdAt']) ?? '') ?? DateTime.now(),
  );
}

class GroupMessagePage {
  const GroupMessagePage({
    required this.messages,
    required this.hasMoreBefore,
    this.latestId,
  });
  final List<GroupMessage> messages;
  final bool hasMoreBefore;
  final int? latestId;
  factory GroupMessagePage.fromJson(Object? body) {
    final j = asMap(body);
    return GroupMessagePage(
      messages: asMapList(j['messages']).map(GroupMessage.fromJson).toList(),
      hasMoreBefore: asBool(j['hasMoreBefore']),
      latestId: asInt(j['latestId']),
    );
  }
}

class GroupPage<T> {
  const GroupPage(this.content);
  final List<T> content;
}

class GroupUserLookup {
  const GroupUserLookup({
    required this.id,
    required this.nickname,
    required this.level,
  });
  final int id, level;
  final String nickname;
  factory GroupUserLookup.fromJson(Map<String, dynamic> j) => GroupUserLookup(
    id: asInt(pick(j, ['userId', 'id'])) ?? 0,
    nickname: asString(j['nickname']) ?? '모험가',
    level: asInt(j['level']) ?? 1,
  );
}

GroupRole? _role(String? raw) => _enum<GroupRole?>(raw, {
  'OWNER': GroupRole.owner,
  'MEMBER': GroupRole.member,
}, null);
GroupMembershipStatus? _membership(String? raw) =>
    _enum<GroupMembershipStatus?>(raw, {
      'INVITED': GroupMembershipStatus.invited,
      'PENDING_APPROVAL': GroupMembershipStatus.pendingApproval,
      'ACTIVE': GroupMembershipStatus.active,
      'REJECTED': GroupMembershipStatus.rejected,
      'LEFT': GroupMembershipStatus.left,
      'REMOVED': GroupMembershipStatus.removed,
    }, null);
