import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';

enum MindAidSender { assistant, user }

class MindAidMessage {
  const MindAidMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.status,
  });

  final String id;
  final MindAidSender sender;
  final String text;
  final DateTime createdAt;
  final String? status;
}

class MindAidSuggestion {
  const MindAidSuggestion({
    required this.id,
    required this.label,
    this.iconAsset,
  });

  final String id;
  final String label;
  final String? iconAsset;
}

class MindAidScreen extends StatefulWidget {
  const MindAidScreen({
    super.key,
    this.messages = const [],
    this.suggestions = const [],
    this.disclaimerText,
    this.onSendMessage,
    this.onSuggestionSelected,
    this.onNotificationTap,
  });

  final List<MindAidMessage> messages;
  final List<MindAidSuggestion> suggestions;
  final String? disclaimerText;
  final ValueChanged<String>? onSendMessage;
  final ValueChanged<MindAidSuggestion>? onSuggestionSelected;
  final VoidCallback? onNotificationTap;

  @override
  State<MindAidScreen> createState() => _MindAidScreenState();
}

class _MindAidScreenState extends State<MindAidScreen> {
  final TextEditingController _messageController = TextEditingController();

  bool get _canSend => _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageChanged);
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_handleMessageChanged)
      ..dispose();
    super.dispose();
  }

  void _handleMessageChanged() {
    setState(() {});
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    widget.onSendMessage?.call(message);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _MindAidColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AnimatedMindAidSection(
              delay: 0,
              child: _MindAidHeader(
                onNotificationTap: widget.onNotificationTap,
              ),
            ),
            const _AnimatedMindAidSection(
              delay: 70,
              child: _AssistantProfileCard(),
            ),
            Expanded(
              child: _AnimatedMindAidSection(
                delay: 130,
                child: _MindAidConversation(
                  messages: widget.messages,
                  suggestions: widget.suggestions,
                  disclaimerText: widget.disclaimerText,
                  onSuggestionSelected: widget.onSuggestionSelected,
                ),
              ),
            ),
            _AnimatedMindAidSection(
              delay: 180,
              child: _MindAidComposer(
                controller: _messageController,
                canSend: _canSend,
                onSend: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MindAidHeader extends StatelessWidget {
  const _MindAidHeader({this.onNotificationTap});

  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _MindAidColors.sun,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const _MindAidAssetImage(
            assetName: 'logo.png 3.png',
            width: 34,
            height: 34,
            fallbackIcon: Icons.psychology_alt_outlined,
          ),
          const SizedBox(width: 8),
          const _MindAidAssetImage(
            assetName: 'MindMate.png',
            height: 30,
            fit: BoxFit.contain,
            fallbackText: 'MindMate',
          ),
          const Spacer(),
          Tooltip(
            message: 'Notifications',
            child: IconButton(
              onPressed: onNotificationTap,
              icon: const _MindAidAssetImage(
                assetName: 'Notification.png',
                width: 26,
                height: 26,
                fallbackIcon: Icons.notifications,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantProfileCard extends StatelessWidget {
  const _AssistantProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: _MindAidColors.softCream,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: const _MindAidAssetImage(
              assetName: 'Group 1383.png',
              fit: BoxFit.cover,
              fallbackIcon: Icons.support_agent_rounded,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MindAid', style: _MindAidText.profileTitle),
                SizedBox(height: 3),
                Text(
                  'Always here to support you',
                  style: _MindAidText.profileSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MindAidConversation extends StatelessWidget {
  const _MindAidConversation({
    required this.messages,
    required this.suggestions,
    required this.disclaimerText,
    required this.onSuggestionSelected,
  });

  final List<MindAidMessage> messages;
  final List<MindAidSuggestion> suggestions;
  final String? disclaimerText;
  final ValueChanged<MindAidSuggestion>? onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          sliver: messages.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyConversationSpace(),
                )
              : SliverList.separated(
                  itemCount: messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    return _MessageBubble(message: messages[index]);
                  },
                ),
        ),
        if (suggestions.isNotEmpty)
          SliverToBoxAdapter(
            child: _SuggestionPanel(
              suggestions: suggestions,
              onSuggestionSelected: onSuggestionSelected,
            ),
          ),
        if (disclaimerText != null && disclaimerText!.trim().isNotEmpty)
          SliverToBoxAdapter(
            child: _DisclaimerPanel(text: disclaimerText!.trim()),
          ),
      ],
    );
  }
}

class _EmptyConversationSpace extends StatelessWidget {
  const _EmptyConversationSpace();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final MindAidMessage message;

  bool get _isUser => message.sender == MindAidSender.user;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (_isUser ? .72 : .86),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _isUser
                ? _MindAidColors.userBubble
                : _MindAidColors.aiBubble,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(_isUser ? 16 : 4),
              bottomRight: Radius.circular(_isUser ? 4 : 16),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: _isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(message.text, style: _MindAidText.message),
                const SizedBox(height: 8),
                if (message.status != null && message.status!.trim().isNotEmpty)
                  Text(message.status!.trim(), style: _MindAidText.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  final List<MindAidSuggestion> suggestions;
  final ValueChanged<MindAidSuggestion>? onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: Column(
        children: [
          const Text(
            'Quick suggestions:',
            style: _MindAidText.suggestionsTitle,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final suggestion in suggestions)
                _SuggestionChip(
                  suggestion: suggestion,
                  onTap: () => onSuggestionSelected?.call(suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.suggestion, required this.onTap});

  final MindAidSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _MindAidColors.chip,
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      shadowColor: const Color(0x26000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 142, maxWidth: 170),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (suggestion.iconAsset != null) ...[
                  _MindAidAssetImage(
                    assetName: suggestion.iconAsset!,
                    width: 16,
                    height: 16,
                    fallbackIcon: Icons.auto_awesome,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    suggestion.label,
                    overflow: TextOverflow.ellipsis,
                    style: _MindAidText.suggestion,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisclaimerPanel extends StatelessWidget {
  const _DisclaimerPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      decoration: const BoxDecoration(color: _MindAidColors.disclaimer),
      child: Text(text, style: _MindAidText.disclaimer),
    );
  }
}

class _MindAidComposer extends StatelessWidget {
  const _MindAidComposer({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 14, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE3E3E3))),
          boxShadow: [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: _MindAidText.inputHint,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: _MindAidColors.inputBorder,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: _MindAidColors.sun,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Voice input',
              child: IconButton(
                onPressed: null,
                icon: const Icon(Icons.mic, size: 26),
              ),
            ),
            const SizedBox(width: 2),
            _SendButton(canSend: canSend, onSend: onSend),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.canSend, required this.onSend});

  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Send message',
      child: AnimatedScale(
        scale: canSend ? 1 : .94,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: canSend ? _MindAidColors.sun : _MindAidColors.softSun,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: canSend ? onSend : null,
            icon: const Icon(
              Icons.send_outlined,
              color: Colors.black,
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}

class _MindAidAssetImage extends StatelessWidget {
  const _MindAidAssetImage({
    required this.assetName,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackIcon,
    this.fallbackText,
  });

  final String assetName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData? fallbackIcon;
  final String? fallbackText;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppAssets.messageImages}/$assetName',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) {
        if (fallbackText != null) {
          return Text(fallbackText!, style: _MindAidText.brandFallback);
        }

        return SizedBox(
          width: width,
          height: height,
          child: Icon(
            fallbackIcon ?? Icons.image_not_supported_outlined,
            color: Colors.black87,
          ),
        );
      },
    );
  }
}

class _AnimatedMindAidSection extends StatelessWidget {
  const _AnimatedMindAidSection({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

class _MindAidColors {
  const _MindAidColors._();

  static const background = Color(0xFFFAFAFA);
  static const sun = Color(0xFFFFCD3A);
  static const softSun = Color(0xFFFFE59A);
  static const softCream = Color(0xFFFFF3CF);
  static const aiBubble = Color(0xFFFFF6D9);
  static const userBubble = Color(0xFFE2E2E2);
  static const chip = Color(0xFFE1E1E1);
  static const disclaimer = Color(0xFFFFFAEA);
  static const inputBorder = Color(0xFF9F9F9F);
  static const text = Color(0xFF6F5613);
  static const muted = Color(0xFF8B8B8B);
}

class _MindAidText {
  const _MindAidText._();

  static const brandFallback = TextStyle(
    color: Colors.black,
    fontSize: 24,
    fontWeight: FontWeight.w900,
  );

  static const profileTitle = TextStyle(
    color: Color(0xFFFFB700),
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  static const profileSubtitle = TextStyle(
    color: Color(0xFFFFB700),
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const message = TextStyle(
    color: _MindAidColors.text,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  static const status = TextStyle(
    color: _MindAidColors.muted,
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const suggestionsTitle = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static const suggestion = TextStyle(
    color: _MindAidColors.text,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const disclaimer = TextStyle(
    color: Colors.black,
    fontSize: 12,
    height: 1.32,
    fontWeight: FontWeight.w500,
  );

  static const inputHint = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
}
