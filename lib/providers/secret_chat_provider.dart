import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../features/secret_chat/domain/secret_chat_safety_validator.dart';
import '../models/secret_chat_model.dart';
import '../models/secret_chat_profile.dart';
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
  SecretChatProfile? _profile;
  SecretChatProfileStats _profileStats = SecretChatProfileStats.empty;
  bool _isProfileLoading = false;
  bool _isProfileSaving = false;
  String? _profileError;
  List<SecretChatModel> _recentPosts = [];
  final Set<String> _pendingLikes = {};
  final Set<String> _pendingSaves = {};

  List<SecretChatModel> get posts => List.unmodifiable(_posts);
  SecretChatFilter get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get canCreate => repository.hasSignedInUser;
  int get savedCount => _posts.where((post) => post.isSaved).length;
  SecretChatProfile? get profile => _profile;
  SecretChatProfileStats get profileStats => _profileStats;
  bool get isProfileLoading => _isProfileLoading;
  bool get isProfileSaving => _isProfileSaving;
  String? get profileError => _profileError;
  List<SecretChatModel> get recentPosts => List.unmodifiable(_recentPosts);

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
            post.categoryList.any(
              (category) => category.toLowerCase().contains(query),
            );
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
    required List<String> categories,
  }) async {
    final validation = validator.validatePost(message);
    if (!validation.isAllowed) {
      _errorMessage = validation.message;
      notifyListeners();
      throw SecretChatValidationException(validation);
    }

    if (categories.isEmpty ||
        categories.length > 3 ||
        categories.toSet().length != categories.length) {
      throw ArgumentError('Choose between 1 and 3 unique categories.');
    }
    final id = repository.newPostId();
    final optimistic = SecretChatModel(
      id: id,
      message: message.trim(),
      createdAt: DateTime.now(),
      category: categories.first,
      categories: categories,
      likeCount: 0,
      commentCount: 0,
      authorId: _profile?.userId,
      authorAlias: _profile?.alias ?? 'Anonymous',
      authorPhotoUrl: _profile?.photoUrl,
      safetyLabels: validation.labels,
      isMine: true,
      isPending: true,
    );
    _posts = [optimistic, ..._posts];
    _selectedFilter = SecretChatFilter.mine;
    _errorMessage = null;
    notifyListeners();
    try {
      await repository.createPost(
        message: message,
        categories: categories,
        postId: id,
        safetyLabels: validation.labels,
      );
      _replacePost(optimistic.copyWith(isPending: false, hasFailed: false));
    } catch (error) {
      _replacePost(optimistic.copyWith(isPending: false, hasFailed: true));
      rethrow;
    }
  }

  Future<void> toggleLike(String postId) async {
    final post = _findPost(postId);
    if (post == null || _pendingLikes.contains(postId)) return;
    _pendingLikes.add(postId);
    final optimistic = post.copyWith(
      isLiked: !post.isLiked,
      likeCount: (post.likeCount + (post.isLiked ? -1 : 1)).clamp(0, 1 << 31),
      isPending: true,
    );
    _replacePost(optimistic);
    try {
      await repository.toggleLike(post);
      _replacePost(optimistic.copyWith(isPending: false, hasFailed: false));
    } catch (_) {
      _replacePost(post.copyWith(hasFailed: true));
      rethrow;
    } finally {
      _pendingLikes.remove(postId);
    }
  }

  Future<void> retryPost(String postId) async {
    final post = _findPost(postId);
    if (post == null || !post.hasFailed || post.isPending) return;
    _replacePost(post.copyWith(isPending: true, hasFailed: false));
    try {
      await repository.createPost(
        message: post.message,
        categories: post.categoryList,
        postId: post.id,
        safetyLabels: post.safetyLabels,
      );
      _replacePost(post.copyWith(isPending: false, hasFailed: false));
    } catch (_) {
      _replacePost(post.copyWith(isPending: false, hasFailed: true));
      rethrow;
    }
  }

  Future<void> recordUniqueRead(String postId) async {
    final post = _findPost(postId);
    if (post == null) return;
    final updated = await repository.recordUniqueRead(post);
    _replacePost(updated);
  }

  Future<void> loadProfile() async {
    _isProfileLoading = true;
    _profileError = null;
    notifyListeners();
    try {
      final values = await Future.wait([
        repository.fetchCurrentProfile(),
        repository.fetchProfileStats(),
        repository.fetchRecentPosts(),
      ]);
      _profile = values[0] as SecretChatProfile?;
      _profileStats = values[1] as SecretChatProfileStats;
      _recentPosts = values[2] as List<SecretChatModel>;
    } catch (error) {
      _profileError = _friendlyError(error);
    }
    _isProfileLoading = false;
    notifyListeners();
  }

  Future<void> saveProfile(String alias) async {
    await _runProfileSave(() => repository.saveProfile(alias: alias));
  }

  Future<void> uploadProfilePhoto(Uint8List bytes, String contentType) async {
    await _runProfileSave(
      () => repository.uploadProfilePhoto(bytes, contentType: contentType),
    );
  }

  Future<void> removeProfilePhoto() async {
    await _runProfileSave(repository.removeProfilePhoto);
  }

  Future<void> _runProfileSave(
    Future<SecretChatProfile?> Function() action,
  ) async {
    _isProfileSaving = true;
    _profileError = null;
    notifyListeners();
    try {
      _profile = await action();
      final cleanupWarning = repository.takePhotoCleanupWarning();
      final values = await Future.wait([
        repository.fetchProfileStats(),
        repository.fetchRecentPosts(),
      ]);
      _profileStats = values[0] as SecretChatProfileStats;
      _recentPosts = values[1] as List<SecretChatModel>;
      if (cleanupWarning != null) _profileError = cleanupWarning;
    } catch (error) {
      _profileError = error.toString().replaceFirst(
        'Invalid argument(s): ',
        '',
      );
      rethrow;
    } finally {
      _isProfileSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleSave(String postId) async {
    final post = _findPost(postId);
    if (post == null || _pendingSaves.contains(postId)) return;
    _pendingSaves.add(postId);
    final optimistic = post.copyWith(isSaved: !post.isSaved, isPending: true);
    _replacePost(optimistic);
    try {
      await repository.toggleSave(post);
      _replacePost(optimistic.copyWith(isPending: false, hasFailed: false));
    } catch (_) {
      _replacePost(post.copyWith(hasFailed: true));
      rethrow;
    } finally {
      _pendingSaves.remove(postId);
    }
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

    final original = _findPost(postId);
    if (original != null) {
      _replacePost(original.copyWith(commentCount: original.commentCount + 1));
    }
    try {
      await repository.addComment(
        postId: postId,
        message: message,
        safetyLabels: validation.labels,
      );
    } catch (error, stackTrace) {
      if (original != null) _replacePost(original);
      debugPrint('Unable to send Secret Chat reply: $error');
      debugPrintStack(stackTrace: stackTrace);
      final message = _friendlyError(error);
      _errorMessage = message;
      notifyListeners();
      throw SecretChatActionException(message);
    }

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
    if (error is SecretChatAliasTakenException) return error.toString();
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
