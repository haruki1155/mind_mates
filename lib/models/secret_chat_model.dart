import 'package:flutter/material.dart';

import '../core/utils/firestore_mapper.dart';

enum SecretChatFilter { popular, mine, saved }

class SecretChatModel {
  const SecretChatModel({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.category,
    required this.likeCount,
    required this.commentCount,
    this.authorId,
    this.moderationStatus = 'active',
    this.isLiked = false,
    this.isSaved = false,
    this.isMine = false,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final String category;
  final int likeCount;
  final int commentCount;
  final String? authorId;
  final String moderationStatus;
  final bool isLiked;
  final bool isSaved;
  final bool isMine;

  SecretChatModel copyWith({
    String? id,
    String? message,
    DateTime? createdAt,
    String? category,
    int? likeCount,
    int? commentCount,
    String? authorId,
    String? moderationStatus,
    bool? isLiked,
    bool? isSaved,
    bool? isMine,
  }) {
    return SecretChatModel(
      id: id ?? this.id,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      authorId: authorId ?? this.authorId,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isMine: isMine ?? this.isMine,
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
    return SecretChatModel(
      id: (json['id'] ?? id ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
      category: (json['category'] ?? 'Mental Health').toString(),
      likeCount: intFromFirestore(json['likeCount']),
      commentCount: intFromFirestore(json['commentCount']),
      authorId: authorId,
      moderationStatus: (json['moderationStatus'] ?? 'active').toString(),
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
      'createdAt': createdAt,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'moderationStatus': moderationStatus,
    };
  }
}

class SecretChatComment {
  const SecretChatComment({
    required this.id,
    required this.postId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String message;
  final DateTime createdAt;

  factory SecretChatComment.fromJson(Map<String, dynamic> json, {String? id}) {
    return SecretChatComment(
      id: (json['id'] ?? id ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'postId': postId, 'message': message, 'createdAt': createdAt};
  }
}

class SecretChatCategory {
  const SecretChatCategory({required this.label, required this.color});

  final String label;
  final Color color;
}
