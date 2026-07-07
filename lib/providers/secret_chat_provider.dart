import 'package:flutter/material.dart';

import '../features/secret_chat/domain/secret_chat_safety_validator.dart';
import '../models/secret_chat_model.dart';
import '../repositories/secret_chat_repository.dart';

class SecretChatProvider extends ChangeNotifier {
  SecretChatProvider(
    this.repository, {
    this.validator = const SecretChatSafetyValidator(),
  });

  final SecretChatRepository repository;
  final SecretChatSafetyValidator validator;

  final categories = const [
    SecretChatCategory(label: 'Mental Health', color: Color(0xFFFFC414)),
    SecretChatCategory(label: 'Anxiety', color: Color(0xFFFF7BA5)),
    SecretChatCategory(label: 'Stress', color: Color(0xFFFF9D76)),
    SecretChatCategory(label: 'Gratitude', color: Color(0xFF76A9FF)),
    SecretChatCategory(label: 'Self-care', color: Color(0xFF71D6A4)),
    SecretChatCategory(label: 'School Pressure', color: Color(0xFFB8A7FF)),
    SecretChatCategory(label: 'Support', color: Color(0xFF78C7E8)),
  ];

  List<SecretChatModel> _posts = [];
  SecretChatFilter _selectedFilter = SecretChatFilter.popular;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<SecretChatModel> get posts => List.unmodifiable(_posts);
  SecretChatFilter get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get canCreate => repository.hasSignedInUser;
  int get savedCount => _posts.where((post) => post.isSaved).length;

  List<SecretChatModel> get visiblePosts {
    Iterable<SecretChatModel> result = _posts;
    switch (_selectedFilter) {
      case SecretChatFilter.popular:
        result = result.toList()
          ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case SecretChatFilter.mine:
        result = result.where((post) => post.isMine);
      case SecretChatFilter.saved:
        result = result.where((post) => post.isSaved);
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((post) {
        return post.message.toLowerCase().contains(query) ||
            post.category.toLowerCase().contains(query);
      });
    }

    return result.toList();
  }

  Future<void> loadPosts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _posts = await repository.fetchPosts();
    } catch (error) {
      _posts = [];
      _errorMessage = _friendlyError(error);
    }

    _isLoading = false;
    notifyListeners();
  }

  void setFilter(SecretChatFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> createPost({
    required String message,
    required String category,
  }) async {
    final validation = validator.validatePost(message);
    if (!validation.isAllowed) {
      _errorMessage = validation.message;
      notifyListeners();
      throw SecretChatValidationException(validation);
    }

    final post = await repository.createPost(
      message: message,
      category: category,
      safetyLabels: validation.labels,
    );
    _posts = [post, ..._posts];
    _selectedFilter = SecretChatFilter.mine;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> toggleLike(String postId) async {
    final post = _findPost(postId);
    if (post == null) return;
    final updated = await repository.toggleLike(post);
    _replacePost(updated);
  }

  Future<void> toggleSave(String postId) async {
    final post = _findPost(postId);
    if (post == null) return;
    final updated = await repository.toggleSave(post);
    _replacePost(updated);
  }

  Future<List<SecretChatComment>> fetchComments(String postId) {
    return repository.fetchComments(postId);
  }

  Future<void> addComment({
    required String postId,
    required String message,
  }) async {
    final validation = validator.validateComment(message);
    if (!validation.isAllowed) {
      _errorMessage = validation.message;
      notifyListeners();
      throw SecretChatValidationException(validation);
    }

    try {
      await repository.addComment(
        postId: postId,
        message: message,
        safetyLabels: validation.labels,
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to send Secret Chat reply: $error');
      debugPrintStack(stackTrace: stackTrace);
      final message = _friendlyError(error);
      _errorMessage = message;
      notifyListeners();
      throw SecretChatActionException(message);
    }

    _posts = [
      for (final post in _posts)
        post.id == postId
            ? post.copyWith(commentCount: post.commentCount + 1)
            : post,
    ];
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _replacePost(SecretChatModel updated) {
    _posts = [
      for (final post in _posts) post.id == updated.id ? updated : post,
    ];
    notifyListeners();
  }

  SecretChatModel? _findPost(String postId) {
    for (final post in _posts) {
      if (post.id == postId) return post;
    }
    return null;
  }

  String _friendlyError(Object error) {
    if (error is SecretChatAuthException) {
      return 'Please sign in to use Secret Chat.';
    }
    if (error is SecretChatValidationException) {
      return error.result.message;
    }
    if (error is SecretChatThreadUnavailableException) {
      return 'This thread is no longer available for replies.';
    }
    return 'Secret Chat is unavailable right now. Please try again.';
  }
}

class SecretChatValidationException implements Exception {
  const SecretChatValidationException(this.result);

  final SecretChatValidationResult result;

  @override
  String toString() => result.message;
}

class SecretChatActionException implements Exception {
  const SecretChatActionException(this.message);

  final String message;

  @override
  String toString() => message;
}
