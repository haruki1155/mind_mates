import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/secret_chat_provider.dart';
import '../screens/secret_chat_screen.dart';

class SecretChatPage extends StatefulWidget {
  const SecretChatPage({super.key});

  @override
  State<SecretChatPage> createState() => _SecretChatPageState();
}

class _SecretChatPageState extends State<SecretChatPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SecretChatProvider>().loadPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SecretChatProvider>();

    return SecretChatScreen(
      posts: provider.visiblePosts,
      categories: provider.categories,
      selectedFilter: provider.selectedFilter,
      savedCount: provider.savedCount,
      searchQuery: provider.searchQuery,
      isLoading: provider.isLoading,
      errorMessage: provider.errorMessage,
      canCreate: provider.canCreate,
      onFilterChanged: provider.setFilter,
      onSearchChanged: provider.setSearchQuery,
      onCreatePost: provider.createPost,
      onToggleLike: provider.toggleLike,
      onToggleSave: provider.toggleSave,
      onFetchComments: provider.fetchComments,
      onAddComment: provider.addComment,
      onRetry: provider.loadPosts,
      onBack: () => Navigator.of(context).maybePop(),
    );
  }
}
