import 'package:flutter/material.dart';

import '../core/utils/firestore_mapper.dart';

enum SecretChatFilter { popular, mine, saved }

class SecretChatModel {
  const SecretChatModel({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.category,
    this.categories = const [],
    required this.likeCount,
    required this.commentCount,
    this.readCount = 0,
    this.authorId,
    this.authorAlias = 'Anonymous',
    this.authorPhotoUrl,
    this.moderationStatus = 'active',
    this.safetyLabels = const [],
    this.isAnonymous = true,
    this.isLiked = false,
    this.isSaved = false,
    this.isMine = false,
    this.isPending = false,
    this.hasFailed = false,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final String category;
  final List<String> categories;
  final int likeCount;
  final int commentCount;
  final int readCount;
  final String? authorId;
  final String authorAlias;
  final String? authorPhotoUrl;
  final String moderationStatus;
  final List<String> safetyLabels;
  final bool isAnonymous;
  final bool isLiked;
  final bool isSaved;
  final bool isMine;
  final bool isPending;
  final bool hasFailed;

  List<String> get categoryList =>
      categories.isEmpty ? <String>[category] : categories;
  String get primaryCategory => categoryList.first;

  SecretChatModel copyWith({
    String? id,
    String? message,
    DateTime? createdAt,
    String? category,
    List<String>? categories,
    int? likeCount,
    int? commentCount,
    int? readCount,
    String? authorId,
    String? authorAlias,
    String? authorPhotoUrl,
    String? moderationStatus,
    List<String>? safetyLabels,
    bool? isAnonymous,
    bool? isLiked,
    bool? isSaved,
    bool? isMine,
    bool? isPending,
    bool? hasFailed,
  }) {
    return SecretChatModel(
      id: id ?? this.id,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      readCount: readCount ?? this.readCount,
      authorId: authorId ?? this.authorId,
      authorAlias: authorAlias ?? this.authorAlias,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      safetyLabels: safetyLabels ?? this.safetyLabels,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isMine: isMine ?? this.isMine,
      isPending: isPending ?? this.isPending,
      hasFailed: hasFailed ?? this.hasFailed,
    );
  }

  factory SecretChatModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
    String? currentUserId,
    bool isLiked = false,
    bool isSaved = false,
  }) {
    final authorId = json['authorId']?.toString();
    final categories = _stringList(json['categories']);
    final legacyCategory = (json['category'] ?? 'Mental Health').toString();
    return SecretChatModel(
      id: (json['id'] ?? id ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
      category: categories.isEmpty ? legacyCategory : categories.first,
      categories: categories.isEmpty ? <String>[legacyCategory] : categories,
      likeCount: intFromFirestore(json['likeCount']),
      commentCount: intFromFirestore(json['commentCount']),
      readCount: intFromFirestore(json['readCount']),
      authorId: authorId,
      authorAlias: (json['authorAlias'] ?? 'Anonymous').toString(),
      authorPhotoUrl: _optionalString(json['authorPhotoUrl']),
      moderationStatus: (json['moderationStatus'] ?? 'active').toString(),
      safetyLabels: _stringList(json['safetyLabels']),
      isAnonymous: boolFromFirestore(json['isAnonymous'], fallback: true),
      isLiked: isLiked,
      isSaved: isSaved,
      isMine: currentUserId != null && authorId == currentUserId,
    );
  }

  Map<String, dynamic> toJson({required String authorId}) {
    return {
      'authorId': authorId,
      'message': message,
      'category': category,
      'categories': categoryList,
      'createdAt': createdAt,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'readCount': readCount,
      'moderationStatus': moderationStatus,
      'safetyLabels': safetyLabels,
      'isAnonymous': isAnonymous,
    };
  }
}

class SecretChatComment {
  const SecretChatComment({
    required this.id,
    required this.postId,
    required this.message,
    required this.createdAt,
    this.authorId,
    this.authorAlias = 'Anonymous',
    this.authorPhotoUrl,
    this.moderationStatus = 'active',
    this.safetyLabels = const [],
    this.isAnonymous = true,
    this.isPending = false,
    this.hasFailed = false,
  });

  final String id;
  final String postId;
  final String message;
  final DateTime createdAt;
  final String? authorId;
  final String authorAlias;
  final String? authorPhotoUrl;
  final String moderationStatus;
  final List<String> safetyLabels;
  final bool isAnonymous;
  final bool isPending;
  final bool hasFailed;

  SecretChatComment copyWith({bool? isPending, bool? hasFailed}) {
    return SecretChatComment(
      id: id,
      postId: postId,
      message: message,
      createdAt: createdAt,
      authorId: authorId,
      authorAlias: authorAlias,
      authorPhotoUrl: authorPhotoUrl,
      moderationStatus: moderationStatus,
      safetyLabels: safetyLabels,
      isAnonymous: isAnonymous,
      isPending: isPending ?? this.isPending,
      hasFailed: hasFailed ?? this.hasFailed,
    );
  }

  factory SecretChatComment.fromJson(Map<String, dynamic> json, {String? id}) {
    return SecretChatComment(
      id: (json['id'] ?? id ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
      authorId: json['authorId']?.toString(),
      authorAlias: (json['authorAlias'] ?? 'Anonymous').toString(),
      authorPhotoUrl: _optionalString(json['authorPhotoUrl']),
      moderationStatus: (json['moderationStatus'] ?? 'active').toString(),
      safetyLabels: _stringList(json['safetyLabels']),
      isAnonymous: boolFromFirestore(json['isAnonymous'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorId': authorId,
      'message': message,
      'createdAt': createdAt,
      'moderationStatus': moderationStatus,
      'safetyLabels': safetyLabels,
      'isAnonymous': isAnonymous,
    };
  }
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

class SecretChatCategory {
  const SecretChatCategory({required this.label, required this.color});

  final String label;
  final Color color;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
