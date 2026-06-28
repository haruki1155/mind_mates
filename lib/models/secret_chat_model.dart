import 'package:flutter/material.dart';

enum SecretChatFilter { popular, mine, saved }

class SecretChatModel {
  const SecretChatModel({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.category,
    required this.likeCount,
    required this.commentCount,
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
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isMine: isMine ?? this.isMine,
    );
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
}

class SecretChatCategory {
  const SecretChatCategory({required this.label, required this.color});

  final String label;
  final Color color;
}
