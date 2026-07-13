import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/journal_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/user_provider.dart';
import '../models/journal_prompt_model.dart';
import '../services/journal_draft_store.dart';

const _journalBackground = Color(0xFFF7F1DF);
const _journalGold = Color(0xFFFFC414);

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = _userId(context);
    if (userId == null || _loadedUserId == userId) return;
    _loadedUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<JournalProvider>().loadRecentJournals(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    final entries = provider.journals
        .where((item) => !item.isArchived)
        .toList();
    final days = entries
        .map((item) => DateUtils.dateOnly(item.createdAt))
        .toSet()
        .length;
    return Scaffold(
      backgroundColor: _journalBackground,
      appBar: AppBar(
        title: const Text('My Journal'),
        backgroundColor: _journalGold,
        foregroundColor: Colors.black,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Tooltip(
              message: 'Private to you',
              child: Icon(Icons.lock_outline),
            ),
          ),
        ],
      ),
      body: _userId(context) == null
          ? const _JournalMessage(
              icon: Icons.lock_outline,
              title: 'Sign in to use your private journal',
              message: 'Your reflections are saved only to your account.',
            )
          : RefreshIndicator(
              onRefresh: () => provider.loadRecentJournals(_userId(context)!),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 38),
                children: [
                  const _WelcomeCard(),
                  const SizedBox(height: 20),
                  const Text(
                    'What do you need right now?',
                    style: _TitleStyle(),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.sizeOf(context).width > 650
                        ? 3
                        : 2,
                    childAspectRatio: .8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      for (final mode in JournalMode.values)
                        _ModeCard(mode: mode, onTap: () => _openEditor(mode)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _JourneyCard(entries: entries, reflectionDays: days),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Recent reflections', style: _TitleStyle()),
                      ),
                      if (entries.isNotEmpty)
                        Text(
                          '${entries.length} total',
                          style: const TextStyle(color: Colors.black54),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (provider.isLoading && entries.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (provider.errorMessage != null && entries.isEmpty)
                    _JournalMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load reflections',
                      message: 'Pull to refresh or try again.',
                      action: () =>
                          provider.loadRecentJournals(_userId(context)!),
                    )
                  else if (entries.isEmpty)
                    const _JournalMessage(
                      icon: Icons.auto_stories_outlined,
                      title: 'Your journal is ready',
                      message:
                          'Choose any reflection mode. There is no pressure to write perfectly.',
                    )
                  else
                    for (final entry in entries.take(20)) ...[
                      _EntryCard(entry: entry, onTap: () => _openDetail(entry)),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 12),
                  const Text(
                    'Your entries describe patterns you recorded. They are not a diagnosis or clinical assessment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _openEditor(JournalMode mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => JournalEditorScreen(mode: mode)),
    );
  }

  Future<void> _openDetail(JournalModel entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JournalDetailScreen(entry: entry),
      ),
    );
  }
}

class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({super.key, required this.mode, this.entry});
  final JournalMode mode;
  final JournalModel? entry;

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final _controller = TextEditingController();
  final _tagController = TextEditingController();
  final _draftStore = JournalDraftStore();
  final List<JournalPromptResponse> _responses = [];
  Timer? _draftTimer;
  int _step = 0;
  int? _moodLevel;
  String? _moodLabel;
  String? _category;
  JournalFeelingAfter _feelingAfter = JournalFeelingAfter.skipped;
  bool _restored = false;

  List<JournalPromptModel> get _prompts =>
      journalPrompts[widget.mode] ?? const [];
  bool get _atReflection => _step >= _prompts.length;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _responses.addAll(entry.responses);
      if (entry.responses.isEmpty) _controller.text = entry.content;
      _moodLevel = entry.moodLevel;
      _moodLabel = entry.moodLabel;
      _category = entry.category;
      _feelingAfter = entry.feelingAfter;
      _step = _prompts.length;
    }
    _controller.addListener(_scheduleDraft);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored || widget.entry != null) return;
    _restored = true;
    final userId = _userId(context);
    if (userId == null) return;
    _draftStore.read(userId).then((draft) {
      if (!mounted || draft == null || draft['mode'] != widget.mode.name) {
        return;
      }
      setState(() {
        _controller.text = draft['content']?.toString() ?? '';
        _step = (draft['step'] as int? ?? 0).clamp(0, _prompts.length);
        _responses
          ..clear()
          ..addAll(
            (draft['responses'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map(
                  (item) => JournalPromptResponse.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ),
          );
        _moodLevel = draft['moodLevel'] as int?;
        _moodLabel = draft['moodLabel']?.toString();
        _category = draft['category']?.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your saved draft was restored.')),
      );
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _controller.removeListener(_scheduleDraft);
    _controller.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    return Scaffold(
      backgroundColor: _journalBackground,
      appBar: AppBar(
        title: Text(widget.mode.label),
        backgroundColor: _journalGold,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (!_atReflection)
            _PromptProgress(current: _step + 1, total: _prompts.length),
          const SizedBox(height: 14),
          Text(
            _atReflection
                ? 'Complete your reflection'
                : _prompts[_step].question,
            style: const TextStyle(
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Everything here is optional except having something to save.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          if (!_atReflection) ...[
            TextField(
              controller: _controller,
              minLines: 8,
              maxLines: 16,
              maxLength: 10000,
              decoration: _inputDecoration('Write in your own words…'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _nextPrompt,
                  child: Text(
                    _step == _prompts.length - 1 ? 'Continue' : 'Next',
                  ),
                ),
              ],
            ),
          ] else ...[
            _MoodSelector(
              selected: _moodLabel,
              onSelected: (label, level) => setState(() {
                _moodLabel = label;
                _moodLevel = level;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _category,
              decoration: _inputDecoration('Optional category'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No category'),
                ),
                for (final item in _categories)
                  DropdownMenuItem<String?>(value: item, child: Text(item)),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagController,
              decoration: _inputDecoration(
                'Optional tags, separated by commas',
              ),
            ),
            const SizedBox(height: 18),
            const Text('How do you feel after writing?', style: _TitleStyle()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final value in JournalFeelingAfter.values)
                  ChoiceChip(
                    label: Text(
                      value == JournalFeelingAfter.same
                          ? 'About the same'
                          : _capitalize(value.name),
                    ),
                    selected: _feelingAfter == value,
                    onSelected: (_) => setState(() => _feelingAfter = value),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: provider.isSaving ? null : _save,
              icon: provider.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(
                widget.entry == null ? 'Save privately' : 'Save changes',
              ),
            ),
            if (widget.mode == JournalMode.letItOut &&
                widget.entry == null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _releaseDraft,
                child: const Text('Release it without saving'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _nextPrompt() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _responses.removeWhere((item) => item.promptId == _prompts[_step].id);
      _responses.add(
        JournalPromptResponse(promptId: _prompts[_step].id, response: text),
      );
    }
    _controller.clear();
    setState(() => _step++);
  }

  Future<void> _save() async {
    final userId = _userId(context);
    if (userId == null) return;
    final current = _controller.text.trim();
    final contentParts = [
      ..._responses.map((item) => item.response),
      if (current.isNotEmpty) current,
    ];
    if (contentParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      return;
    }
    final tags = _tagController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(5)
        .toList();
    final old = widget.entry;
    final entry = JournalModel(
      id: old?.id ?? '',
      userId: userId,
      mode: widget.mode,
      content: contentParts.join('\n\n'),
      moodLevel: _moodLevel,
      moodLabel: _moodLabel,
      feelingAfter: _feelingAfter,
      category: _category,
      tags: tags.isEmpty ? old?.tags ?? const [] : tags,
      promptIds: _responses.map((item) => item.promptId).toList(),
      responses: _responses,
      isFavorite: old?.isFavorite ?? false,
      isArchived: old?.isArchived ?? false,
      createdAt: old?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final saved = await context.read<JournalProvider>().saveEntry(entry);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save your reflection. Try again.'),
        ),
      );
      return;
    }
    await _draftStore.clear(userId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _scheduleDraft() {
    final userId = _userId(context);
    if (userId == null || widget.entry != null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), () {
      _draftStore.write(userId, {
        'mode': widget.mode.name,
        'content': _controller.text,
        'step': _step,
        'responses': _responses.map((item) => item.toJson()).toList(),
        'moodLevel': _moodLevel,
        'moodLabel': _moodLabel,
        'category': _category,
      });
    });
  }

  Future<void> _releaseDraft() async {
    final userId = _userId(context);
    if (userId != null) await _draftStore.clear(userId);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('You do not have to carry every thought forever.'),
      ),
    );
  }
}

class JournalDetailScreen extends StatelessWidget {
  const JournalDetailScreen({super.key, required this.entry});
  final JournalModel entry;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    final current =
        provider.journals.where((item) => item.id == entry.id).firstOrNull ??
        entry;
    return Scaffold(
      backgroundColor: _journalBackground,
      appBar: AppBar(
        title: const Text('Reflection'),
        backgroundColor: _journalGold,
        actions: [
          IconButton(
            tooltip: current.isFavorite ? 'Remove favorite' : 'Favorite',
            onPressed: provider.isSaving
                ? null
                : () => provider.toggleFavorite(current),
            icon: Icon(current.isFavorite ? Icons.star : Icons.star_border),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    JournalEditorScreen(mode: current.mode, entry: current),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _delete(context, current),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(current.mode.label, style: const _TitleStyle()),
          const SizedBox(height: 5),
          Text(
            _formatDate(current.createdAt),
            style: const TextStyle(color: Colors.black54),
          ),
          if (current.moodLabel != null) ...[
            const SizedBox(height: 12),
            Chip(label: Text('Before: ${current.moodLabel}')),
          ],
          const SizedBox(height: 18),
          if (current.responses.isNotEmpty)
            for (final response in current.responses) ...[
              Text(
                _promptText(response.promptId),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                response.response,
                style: const TextStyle(fontSize: 15, height: 1.55),
              ),
              const SizedBox(height: 18),
            ]
          else
            Text(
              current.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          if (current.category != null || current.tags.isNotEmpty) ...[
            const Divider(height: 32),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (current.category != null)
                  Chip(label: Text(current.category!)),
                for (final tag in current.tags) Chip(label: Text('#$tag')),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'After writing: ${current.feelingAfter == JournalFeelingAfter.same ? 'About the same' : _capitalize(current.feelingAfter.name)}',
          ),
          const SizedBox(height: 24),
          const Text(
            'This reflection is private and is not a diagnosis.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, JournalModel current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this reflection?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await context.read<JournalProvider>().deleteEntry(
      current.id,
    );
    if (deleted && context.mounted) Navigator.of(context).pop();
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration(color: const Color(0xFFFFE59A)),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline),
            SizedBox(width: 8),
            Text(
              'Private to you',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'A private space to understand yourself, one moment at a time.',
          style: TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'You can skip prompts, write freely, or begin again whenever you want.',
          style: TextStyle(height: 1.4),
        ),
      ],
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onTap});
  final JournalMode mode;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_modeIcon(mode), color: const Color(0xFF8A6500)),
            const SizedBox(height: 8),
            Text(
              mode.label,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    ),
  );
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.entries, required this.reflectionDays});
  final List<JournalModel> entries;
  final int reflectionDays;
  @override
  Widget build(BuildContext context) {
    final categories = <String, int>{};
    for (final entry in entries) {
      final category = entry.category;
      if (category != null) {
        categories[category] = (categories[category] ?? 0) + 1;
      }
    }
    final common = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reflection journey', style: _TitleStyle()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '$reflectionDays',
                  label: 'Reflection days',
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${entries.length}',
                  label: 'Total entries',
                ),
              ),
              Expanded(
                child: _Stat(
                  value: common.isEmpty ? '—' : common.first.key,
                  label: 'Common topic',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      ),
    ],
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});
  final JournalModel entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFE59A),
        child: Icon(_modeIcon(entry.mode)),
      ),
      title: Text(
        entry.mode.label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        entry.content.replaceAll('\n', ' '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: entry.isFavorite
          ? const Icon(Icons.star, color: Color(0xFFE5AC00))
          : const Icon(Icons.chevron_right),
    ),
  );
}

class _MoodSelector extends StatelessWidget {
  const _MoodSelector({required this.selected, required this.onSelected});
  final String? selected;
  final void Function(String, int) onSelected;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('How were you feeling before writing?', style: _TitleStyle()),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final item in const [
            ('Happy', 5),
            ('Calm', 4),
            ('Okay', 3),
            ('Tired', 2),
            ('Lonely', 2),
            ('Sad', 1),
            ('Anxious', 2),
            ('Stressed', 2),
            ('Angry', 1),
            ('Overwhelmed', 1),
          ])
            ChoiceChip(
              label: Text(item.$1),
              selected: selected == item.$1,
              onSelected: (_) => onSelected(item.$1, item.$2),
            ),
        ],
      ),
    ],
  );
}

class _PromptProgress extends StatelessWidget {
  const _PromptProgress({required this.current, required this.total});
  final int current;
  final int total;
  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: current / total,
    minHeight: 7,
    borderRadius: BorderRadius.circular(99),
  );
}

class _JournalMessage extends StatelessWidget {
  const _JournalMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: const Color(0xFFE5AC00)),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const _TitleStyle()),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: action, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}

const _categories = [
  'Academics',
  'Relationships',
  'Family',
  'Work',
  'Finances',
  'Self-esteem',
  'Personal growth',
  'Sleep',
  'Health and wellbeing',
  'Something else',
];

String? _userId(BuildContext context) {
  try {
    final auth = context.read<AuthProvider>();
    final id = auth.userId ?? auth.hydrateCurrentUser();
    if (id != null && id.isNotEmpty) return id;
  } on ProviderNotFoundException {
    // UserProvider is the supported fallback for tests and previews.
  }
  try {
    final id = context.read<UserProvider>().user?.id;
    return id == null || id.isEmpty ? null : id;
  } on ProviderNotFoundException {
    return null;
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
);

BoxDecoration _cardDecoration({Color color = Colors.white}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(16),
  boxShadow: const [
    BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 5)),
  ],
);

IconData _modeIcon(JournalMode mode) => switch (mode) {
  JournalMode.freeWrite => Icons.edit_note,
  JournalMode.understandFeelings => Icons.psychology_outlined,
  JournalMode.letItOut => Icons.air,
  JournalMode.findSomethingGood => Icons.wb_sunny_outlined,
  JournalMode.sortOutThoughts => Icons.account_tree_outlined,
  JournalMode.reflectOnDay => Icons.nights_stay_outlined,
};

String _promptText(String id) {
  for (final prompts in journalPrompts.values) {
    for (final prompt in prompts) {
      if (prompt.id == id) return prompt.question;
    }
  }
  return 'Reflection prompt';
}

String _formatDate(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.month}/${date.day}/${date.year} at $hour:$minute $period';
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

class _TitleStyle extends TextStyle {
  const _TitleStyle()
    : super(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF332B1D),
      );
}
