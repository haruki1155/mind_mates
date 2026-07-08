import 'package:flutter/material.dart';

import '../../../models/secret_chat_model.dart';
import 'secret_chat_background.dart';
import 'secret_chat_avatar.dart';

class SecretChatPostCard extends StatelessWidget {
  const SecretChatPostCard({
    super.key,
    required this.post,
    required this.index,
    required this.categoryColor,
    required this.onLike,
    required this.onSave,
    required this.onComments,
    this.onRetry,
  });

  final SecretChatModel post;
  final int index;
  final Color categoryColor;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComments;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (index.clamp(0, 8) * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 22),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: SecretChatPalette.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SecretChatAvatar(
                  alias: post.authorAlias,
                  photoUrl: post.authorPhotoUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorAlias,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SecretChatPalette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _formatDate(post.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SecretChatPalette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz_rounded, size: 22),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'hide', child: Text('Hide post')),
                    PopupMenuItem(value: 'report', child: Text('Report')),
                  ],
                ),
                if (post.isPending)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 10),
                    child: SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final category in post.categoryList)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (category == post.primaryCategory
                                  ? categoryColor
                                  : SecretChatPalette.background)
                              .withAlpha(
                                category == post.primaryCategory ? 70 : 255,
                              ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            if (post.hasFailed) ...[
              const SizedBox(height: 7),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Not synced. Retry post'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: const Color(0xFFB45309),
                  textStyle: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              post.message,
              style: const TextStyle(
                color: SecretChatPalette.text,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE5E0D4)),
            const SizedBox(height: 10),
            Row(
              children: [
                _AnimatedAction(
                  icon: post.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: post.likeCount.toString(),
                  isActive: post.isLiked,
                  activeColor: SecretChatPalette.sun,
                  onTap: onLike,
                ),
                const SizedBox(width: 26),
                _AnimatedAction(
                  icon: Icons.mode_comment_outlined,
                  label: post.commentCount.toString(),
                  isActive: false,
                  activeColor: SecretChatPalette.text,
                  onTap: onComments,
                ),
                const Spacer(),
                _BookmarkButton(isSaved: post.isSaved, onTap: onSave),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _AnimatedAction extends StatelessWidget {
  const _AnimatedAction({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: isActive ? 1.12 : 1,
              child: Icon(
                icon,
                color: isActive ? activeColor : SecretChatPalette.text,
                size: 28,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: SecretChatPalette.text,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.isSaved, required this.onTap});

  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: isSaved ? 1.12 : 1,
          child: Icon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: isSaved ? SecretChatPalette.sun : SecretChatPalette.text,
            size: 28,
          ),
        ),
      ),
    );
  }
}
