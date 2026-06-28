import 'package:flutter/material.dart';

import '../../../models/secret_chat_model.dart';
import '../screens/secret_chat_screen.dart';
import 'secret_chat_background.dart';

class SecretChatComposeSheet extends StatefulWidget {
  const SecretChatComposeSheet({
    super.key,
    required this.categories,
    required this.onSubmit,
  });

  final List<SecretChatCategory> categories;
  final CreateSecretPost onSubmit;

  @override
  State<SecretChatComposeSheet> createState() => _SecretChatComposeSheetState();
}

class _SecretChatComposeSheetState extends State<SecretChatComposeSheet> {
  final _controller = TextEditingController();
  late String _category = widget.categories.first.label;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4D9B8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Share anonymously',
              style: TextStyle(
                color: SecretChatPalette.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your post appears without your name and stays local for now.',
              style: TextStyle(
                color: SecretChatPalette.muted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in widget.categories)
                  ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category.label,
                    selectedColor: category.color.withAlpha(115),
                    onSelected: (_) {
                      setState(() => _category = category.label);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 7,
              maxLength: 280,
              decoration: InputDecoration(
                hintText: 'What would you like to share?',
                filled: true,
                fillColor: SecretChatPalette.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Post anonymously'),
                style: FilledButton.styleFrom(
                  backgroundColor: SecretChatPalette.sun,
                  foregroundColor: SecretChatPalette.text,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSubmitting = true);
    await widget.onSubmit(message: message, category: _category);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
