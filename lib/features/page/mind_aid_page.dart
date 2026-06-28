import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/mind_aid_provider.dart';
import '/features/counseling/screens/mind_aid_screen.dart';

class MindAidPage extends StatefulWidget {
  const MindAidPage({super.key});

  @override
  State<MindAidPage> createState() => _MindAidPageState();
}

class _MindAidPageState extends State<MindAidPage> {
  final userId = "user_1";

  @override
  void initState() {
    super.initState();
    // Schedule the call after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Prevent calling if widget is disposed
      context.read<MindAidProvider>().loadChat(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MindAidProvider>();

    return MindAidScreen(
      messages: provider.messages,
      suggestions: provider.suggestions,
      isAssistantTyping: provider.isSending,
      onSendMessage: (text) {
        provider.sendMessage(userId, text);
      },
      onSuggestionSelected: (suggestion) {
        provider.selectSuggestion(suggestion, userId);
      },
      onNotificationTap: () {},
      disclaimerText: "AI assistant support only",
    );
  }
}
