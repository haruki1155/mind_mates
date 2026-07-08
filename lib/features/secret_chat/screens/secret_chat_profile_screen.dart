import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/secret_chat_profile.dart';
import '../../../models/secret_chat_model.dart';
import '../../../providers/secret_chat_provider.dart';
import '../widgets/secret_chat_avatar.dart';
import '../widgets/secret_chat_background.dart';

class SecretChatProfileScreen extends StatefulWidget {
  const SecretChatProfileScreen({super.key});

  @override
  State<SecretChatProfileScreen> createState() =>
      _SecretChatProfileScreenState();
}

class _SecretChatProfileScreenState extends State<SecretChatProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  bool _initializedAlias = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SecretChatProvider>().loadProfile();
    });
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SecretChatProvider>();
    final profile = provider.profile;
    if (!_initializedAlias && profile != null) {
      _initializedAlias = true;
      _aliasController.text = profile.alias;
    }
    return Scaffold(
      backgroundColor: SecretChatPalette.background,
      appBar: AppBar(
        title: const Text('Secret Chat Profile'),
        backgroundColor: SecretChatPalette.sun,
        foregroundColor: SecretChatPalette.text,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadProfile,
        child: provider.isProfileLoading && profile == null
            ? ListView(
                children: [
                  SizedBox(height: 280),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  _ProfileHero(profile: profile, onPhoto: _choosePhoto),
                  const SizedBox(height: 20),
                  _AliasCard(
                    formKey: _formKey,
                    controller: _aliasController,
                    saving: provider.isProfileSaving,
                    onSave: _saveAlias,
                  ),
                  if (profile?.photoUrl != null) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: provider.isProfileSaving ? null : _removePhoto,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove profile photo'),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Your post activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                        label: 'Unique reads',
                        value: provider.profileStats.reads,
                        icon: Icons.visibility_outlined,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Reactions',
                        value: provider.profileStats.reactions,
                        icon: Icons.favorite_border_rounded,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Comments',
                        value: provider.profileStats.comments,
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                    ],
                  ),
                  if (provider.profileStats.reads == 0 &&
                      provider.profileStats.reactions == 0 &&
                      provider.profileStats.comments == 0) ...[
                    const SizedBox(height: 18),
                    const _EmptyActivity(),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Recent posts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  if (provider.recentPosts.isEmpty)
                    const _EmptyActivity()
                  else
                    for (final post in provider.recentPosts) ...[
                      _RecentPostCard(post: post),
                      const SizedBox(height: 10),
                    ],
                  if (provider.profileError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      provider.profileError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _PrivacyNote(),
                ],
              ),
      ),
    );
  }

  Future<void> _saveAlias() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await context.read<SecretChatProvider>().saveProfile(
        _aliasController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secret Chat profile updated.')),
        );
      }
    } catch (_) {}
  }

  Future<void> _choosePhoto() async {
    final provider = context.read<SecretChatProvider>();
    if (provider.profile == null) {
      _showError('Save a public name before adding a profile photo.');
      return;
    }
    if (provider.profile?.photoUrl == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Protect your privacy'),
          content: const Text(
            'A face or identifying image can reveal who you are in this pseudonymous community. Continue only with a photo you are comfortable sharing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I understand'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final type = picked.mimeType?.toLowerCase() ?? '';
    final name = picked.name.toLowerCase();
    if (!(type == 'image/jpeg' ||
        type == 'image/png' ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png'))) {
      _showError('Choose a JPEG or PNG image.');
      return;
    }
    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _showError('Choose an image smaller than 5 MB.');
      return;
    }
    final decoded = image_lib.decodeImage(bytes);
    if (decoded == null) {
      _showError('That image could not be opened.');
      return;
    }
    final square = image_lib.copyResizeCropSquare(decoded, size: 512);
    final normalized = Uint8List.fromList(
      image_lib.encodeJpg(square, quality: 84),
    );
    try {
      await provider.uploadProfilePhoto(normalized, 'image/jpeg');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (error) {
      if (mounted) {
        _showError(provider.profileError ?? error.toString());
      }
    }
  }

  Future<void> _removePhoto() async {
    try {
      await context.read<SecretChatProvider>().removeProfilePhoto();
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.onPhoto});
  final SecretChatProfile? profile;
  final VoidCallback onPhoto;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Stack(
        children: [
          SecretChatAvatar(
            alias: profile?.alias ?? 'Anonymous',
            photoUrl: profile?.photoUrl,
            radius: 52,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton.filled(
              onPressed: onPhoto,
              icon: const Icon(Icons.camera_alt_rounded),
              style: IconButton.styleFrom(
                backgroundColor: SecretChatPalette.sun,
                foregroundColor: SecretChatPalette.text,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        profile?.alias ?? 'Anonymous',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 5),
      const Text(
        'Your public pseudonym in Secret Chat',
        style: TextStyle(color: SecretChatPalette.muted),
      ),
    ],
  );
}

class _AliasCard extends StatelessWidget {
  const _AliasCard({
    required this.formKey,
    required this.controller,
    required this.saving,
    required this.onSave,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE9DFAF)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Public name',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Letters, numbers, and single spaces · 30 characters max',
              style: TextStyle(fontSize: 12, color: SecretChatPalette.muted),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              maxLength: 30,
              validator: SecretChatProfile.validateAlias,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.alternate_email_rounded),
                hintText: 'Choose a pseudonym',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: SecretChatPalette.sun,
                  foregroundColor: SecretChatPalette.text,
                ),
                child: saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save profile'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFE1A700)),
          const SizedBox(height: 7),
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: SecretChatPalette.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(14),
    child: Column(
      children: [
        Icon(Icons.forum_outlined, size: 34, color: SecretChatPalette.muted),
        SizedBox(height: 8),
        Text(
          'No post activity yet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(
          'Share your first thought to begin seeing community engagement.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SecretChatPalette.muted),
        ),
      ],
    ),
  );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.shield_outlined, size: 20),
      SizedBox(width: 9),
      Expanded(
        child: Text(
          'Your school ID, real name, email, and account identity are never shown on Secret Chat posts or replies.',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
      ),
    ],
  );
}

class _RecentPostCard extends StatelessWidget {
  const _RecentPostCard({required this.post});

  final SecretChatModel post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9DFAF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final category in post.categoryList)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(category, style: const TextStyle(fontSize: 10)),
                  backgroundColor: SecretChatPalette.background,
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(post.message, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 16),
              Text(' ${post.readCount}'),
              const SizedBox(width: 14),
              const Icon(Icons.favorite_border_rounded, size: 16),
              Text(' ${post.likeCount}'),
              const SizedBox(width: 14),
              const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              Text(' ${post.commentCount}'),
            ],
          ),
        ],
      ),
    );
  }
}
