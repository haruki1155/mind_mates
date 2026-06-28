import 'package:flutter/material.dart';

import '../models/secret_chat_model.dart';
import '../repositories/secret_chat_repository.dart';

class SecretChatProvider extends ChangeNotifier {
  SecretChatProvider(this.repository);

  final SecretChatRepository repository;

  final categories = const [
    SecretChatCategory(label: 'Mental Health', color: Color(0xFFFFC414)),
    SecretChatCategory(label: 'Gratitude', color: Color(0xFF76A9FF)),
    SecretChatCategory(label: 'Anxiety', color: Color(0xFFFF7BA5)),
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
      _errorMessage = error.toString();
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
    final post = await repository.createPost(
      message: message,
      category: category,
    );
    _posts = [post, ..._posts];
    _selectedFilter = SecretChatFilter.mine;
    notifyListeners();
  }

  Future<void> toggleLike(String postId) async {
    final updated = await repository.toggleLike(postId);
    _replacePost(updated);
  }

  Future<void> toggleSave(String postId) async {
    final updated = await repository.toggleSave(postId);
    _replacePost(updated);
  }

  Future<List<SecretChatComment>> fetchComments(String postId) {
    return repository.fetchComments(postId);
  }

  Future<void> addComment({
    required String postId,
    required String message,
  }) async {
    await repository.addComment(postId: postId, message: message);
    final updatedPosts = await repository.fetchPosts();
    _posts = updatedPosts;
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
}
