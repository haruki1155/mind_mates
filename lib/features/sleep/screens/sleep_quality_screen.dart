import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/sleep_provider.dart';
import '../../../routes/route_names.dart';
import '../models/sleep_models.dart';

class SleepQualityScreen extends StatefulWidget {
  const SleepQualityScreen({super.key});

  @override
  State<SleepQualityScreen> createState() => _SleepQualityScreenState();
}

class _SleepQualityScreenState extends State<SleepQualityScreen> {
  String? _userId;
  bool _requested = false;
  bool _consentScheduled = false;
  int _windowDays = 7;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    _userId ??= auth.authenticatedUserId;
    if (_userId == null || _requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<SleepProvider>().load(_userId!);
      if (mounted) _scheduleConsent();
    });
  }

  void _scheduleConsent() {
    final provider = context.read<SleepProvider>();
    if (!provider.needsConsent || _consentScheduled) return;
    _consentScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showConsent());
  }

  Future<void> _showConsent() async {
    if (!mounted || _userId == null) return;
    final choice = await showDialog<SleepConsentChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Choose where your diary is stored'),
        content: const Text(
          'Sleep entries are private wellness notes. You can keep them encrypted on this device, or securely sync them to your account across devices. You can change this later.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, SleepConsentChoice.localOnly),
            child: const Text('Keep on this device'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, SleepConsentChoice.cloud),
            icon: const Icon(Icons.cloud_done_outlined),
            label: const Text('Sync across devices'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    await context.read<SleepProvider>().chooseStorage(_userId!, choice);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SleepProvider>();
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to use the sleep diary.')),
      );
    }
    if (provider.isLoading && provider.entries.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (provider.needsConsent) _scheduleConsent();
    final summary = provider.summary(_windowDays);
    final observations = _windowDays >= 14
        ? provider.observations()
        : const <SleepContributorObservation>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3E8),
      appBar: AppBar(
        title: const Text('Sleep Wellness Journal'),
        backgroundColor: const Color(0xFFFFC414),
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sleep diary settings',
            onSelected: _handleMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: provider.cloudEnabled ? 'revoke' : 'cloud',
                child: Text(
                  provider.cloudEnabled
                      ? 'Keep on device only'
                      : 'Enable cloud sync',
                ),
              ),
              if (provider.syncState == SleepSyncState.pending ||
                  provider.syncState == SleepSyncState.error)
                const PopupMenuItem(
                  value: 'retry',
                  child: Text('Retry cloud sync'),
                ),
              if (provider.entries.isNotEmpty)
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Text('Delete all entries'),
                ),
              if (provider.cloudEnabled)
                const PopupMenuItem(
                  value: 'share_counselor',
                  child: Text('Share summary with counselor'),
                ),
              if (provider.cloudEnabled)
                const PopupMenuItem(
                  value: 'manage_shares',
                  child: Text('Manage counselor sharing'),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.needsConsent || provider.isSaving
            ? null
            : () => _openForm(),
        backgroundColor: const Color(0xFFFFC414),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.bedtime_outlined),
        label: const Text("Log last night's sleep"),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.load(_userId!, force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            _PrivacyBanner(
              provider: provider,
              onRetry: () => provider.retrySync(_userId!),
            ),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 10),
              _MessageCard(message: provider.errorMessage!, error: true),
            ],
            const SizedBox(height: 16),
            const _WellnessNotice(),
            const SizedBox(height: 18),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 14, label: Text('14 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
              ],
              selected: {_windowDays},
              onSelectionChanged: (value) =>
                  setState(() => _windowDays = value.first),
            ),
            const SizedBox(height: 14),
            _SummaryGrid(summary: summary),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showUserSummary(summary, observations),
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Generate sleep summary'),
            ),
            if (summary.entryCount < 3) ...[
              const SizedBox(height: 10),
              const _MessageCard(
                message:
                    'Not enough data yet for schedule regularity or contributor patterns. Add at least three entries.',
              ),
            ],
            if (observations.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text('Possible patterns', style: _SleepText.section),
              const SizedBox(height: 8),
              for (final observation in observations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MessageCard(message: observation.message),
                ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text('Recent entries', style: _SleepText.section),
                ),
                Text('${provider.entries.length} total'),
              ],
            ),
            const SizedBox(height: 10),
            if (provider.entries.isEmpty)
              _EmptyDiary(onLog: _openForm)
            else
              for (final entry in provider.entries)
                _EntryCard(
                  entry: entry,
                  onEdit: () => _openForm(entry),
                  onDelete: () => _deleteEntry(entry),
                ),
            const SizedBox(height: 22),
            const _SafetyCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenu(String value) async {
    final provider = context.read<SleepProvider>();
    if (value == 'cloud') {
      await provider.chooseStorage(_userId!, SleepConsentChoice.cloud);
    } else if (value == 'retry') {
      await provider.retrySync(_userId!);
    } else if (value == 'revoke') {
      final confirmed = await _confirm(
        'Stop cloud sync?',
        'Cloud copies will be deleted. Your encrypted diary will remain on this device.',
      );
      if (confirmed) await provider.revokeCloud(_userId!);
    } else if (value == 'delete_all') {
      final confirmed = await _confirm(
        'Delete every sleep entry?',
        'This permanently removes ${provider.cloudEnabled ? 'both local and cloud copies' : 'the local diary'}.',
      );
      if (confirmed) await provider.deleteAll(_userId!);
    } else if (value == 'share_counselor') {
      await _createCounselorShare();
    } else if (value == 'manage_shares') {
      await _manageCounselorShares();
    }
  }

  Future<void> _createCounselorShare() async {
    final window = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share a sleep summary'),
        content: const Text(
          'Your assigned counselor can receive a read-only, server-generated summary—not your raw diary—for 30 days. Cloud sync does not automatically share anything.',
        ),
        actions: [
          for (final days in [7, 14, 30])
            TextButton(
              onPressed: () => Navigator.pop(context, days),
              child: Text('Last $days days'),
            ),
        ],
      ),
    );
    if (window == null || !mounted) return;
    try {
      final grant = await context.read<SleepProvider>().createCounselorShare(
        window,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Shared ${grant.summaryWindowDays}-day summary until ${_dateLabel(grant.accessExpiresAt)}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A confirmed assigned counselor and cloud sync are required to share a summary.',
          ),
        ),
      );
    }
  }

  Future<void> _manageCounselorShares() async {
    try {
      final shares = await context.read<SleepProvider>().loadCounselorShares(
        _userId!,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Counselor sharing', style: _SleepText.section),
            if (shares.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No summaries are currently shared.'),
              ),
            for (final share in shares)
              ListTile(
                title: Text('Last ${share.summaryWindowDays} days'),
                subtitle: Text(
                  share.revoked
                      ? 'Access stopped'
                      : 'Access ends ${_dateLabel(share.accessExpiresAt)}',
                ),
                trailing: share.revoked
                    ? null
                    : TextButton(
                        onPressed: () async {
                          await context
                              .read<SleepProvider>()
                              .revokeCounselorShare(share.id);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Counselor access stopped.'),
                              ),
                            );
                          }
                        },
                        child: const Text('Stop sharing'),
                      ),
              ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load counselor sharing settings.'),
          ),
        );
      }
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openForm([SleepEntry? entry]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SleepEntryFormScreen(userId: _userId!, entry: entry),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sleep entry saved.')));
    }
  }

  Future<void> _deleteEntry(SleepEntry entry) async {
    if (!await _confirm(
      'Delete this entry?',
      'This removes the sleep entry for ${_formatDate(entry.wakeDateKey)}.',
    )) {
      return;
    }
    if (mounted) {
      await context.read<SleepProvider>().deleteEntry(
        _userId!,
        entry.wakeDateKey,
      );
    }
  }

  Future<void> _showUserSummary(
    SleepWindowSummary summary,
    List<SleepContributorObservation> observations,
  ) async {
    final text = _userSummaryText(summary, observations);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sleep summary', style: _SleepText.section),
            const SizedBox(height: 8),
            Text(text),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sleep summary copied. Sharing it does not give a counselor access.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy summary'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Share.share(text),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share summary'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Based on self-reported entries. This is not a diagnosis, and copying it does not grant counselor access.',
            ),
          ],
        ),
      ),
    );
  }

  String _userSummaryText(
    SleepWindowSummary summary,
    List<SleepContributorObservation> observations,
  ) {
    String duration(double? minutes) => minutes == null
        ? 'Not enough entries'
        : '${(minutes / 60).floor()}h ${minutes.round() % 60}m';
    return [
      'Sleep Wellness Journal — last ${summary.windowDays} days',
      '${summary.entryCount} of ${summary.windowDays} days recorded',
      'Estimated sleep duration: ${duration(summary.averageSleepMinutes)}',
      'Sleep quality: ${summary.averageQuality?.toStringAsFixed(1) ?? 'Not enough entries'}/5',
      if (summary.averageEnergy != null)
        'Energy: ${summary.averageEnergy!.toStringAsFixed(1)}/5',
      if (summary.averageFocus != null)
        'Focus: ${summary.averageFocus!.toStringAsFixed(1)}/5',
      if (summary.comparisonSleepMinutes != null)
        'Recent change: ${summary.comparisonSleepMinutes! >= 0 ? '+' : ''}${summary.comparisonSleepMinutes!.round()} minutes compared with the previous period',
      if (observations.isNotEmpty) observations.first.message,
      'Self-reported wellness information only; not a diagnosis or proof of cause.',
    ].join('\n');
  }
}

class SleepEntryFormScreen extends StatefulWidget {
  const SleepEntryFormScreen({super.key, required this.userId, this.entry});
  final String userId;
  final SleepEntry? entry;

  @override
  State<SleepEntryFormScreen> createState() => _SleepEntryFormScreenState();
}

class _SleepEntryFormScreenState extends State<SleepEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _wakeDate;
  late TimeOfDay _attempted;
  late TimeOfDay _onset;
  late TimeOfDay _finalWake;
  late TimeOfDay _outOfBed;
  late final TextEditingController _awakenings;
  late final TextEditingController _awakeMinutes;
  late final TextEditingController _napCount;
  late final TextEditingController _napMinutes;
  int _restfulness = 3;
  int _sleepiness = 3;
  int _quality = 3;
  int? _energy;
  int? _focus;
  bool _showDaytime = false;
  final Set<String> _contributors = {};
  final Set<String> _concerns = {};
  String? _chronologyError;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _wakeDate = entry == null
        ? SleepCalculator.manilaDate(DateTime.now())
        : SleepEntry.dateFromWakeKey(entry.wakeDateKey);
    _attempted = _time(
      entry?.attemptedSleepAt,
      const TimeOfDay(hour: 23, minute: 0),
    );
    _onset = _time(entry?.sleepOnsetAt, const TimeOfDay(hour: 23, minute: 30));
    _finalWake = _time(entry?.finalWakeAt, const TimeOfDay(hour: 7, minute: 0));
    _outOfBed = _time(entry?.outOfBedAt, const TimeOfDay(hour: 7, minute: 15));
    _awakenings = TextEditingController(text: '${entry?.awakeningCount ?? 0}');
    _awakeMinutes = TextEditingController(text: '${entry?.awakeMinutes ?? 0}');
    _napCount = TextEditingController(text: '${entry?.napCount ?? 0}');
    _napMinutes = TextEditingController(text: '${entry?.napMinutes ?? 0}');
    _restfulness = entry?.restfulness ?? 3;
    _sleepiness = entry?.daytimeSleepiness ?? 3;
    _quality = entry?.perceivedQuality ?? 3;
    _energy = entry?.energy;
    _focus = entry?.focus;
    _showDaytime = _energy != null || _focus != null;
    _contributors.addAll(entry?.contributorTags ?? const {});
    _concerns.addAll(entry?.concernTags ?? const {});
  }

  TimeOfDay _time(DateTime? value, TimeOfDay fallback) => value == null
      ? fallback
      : TimeOfDay(hour: value.hour, minute: value.minute);

  @override
  void dispose() {
    _awakenings.dispose();
    _awakeMinutes.dispose();
    _napCount.dispose();
    _napMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<SleepProvider>().isSaving;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Log sleep' : 'Edit sleep'),
        backgroundColor: const Color(0xFFFFC414),
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('When did you sleep?', style: _SleepText.section),
            const SizedBox(height: 6),
            const Text('Times are anchored to your Asia/Manila wake date.'),
            const SizedBox(height: 12),
            ListTile(
              tileColor: const Color(0xFFFFF7D5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Wake date'),
              subtitle: Text(_dateLabel(_wakeDate)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 10),
            _TimeRow(
              label: 'Attempted sleep',
              value: _attempted,
              onTap: () => _pickTime('attempted'),
            ),
            _TimeRow(
              label: 'Estimated sleep onset',
              value: _onset,
              onTap: () => _pickTime('onset'),
            ),
            _TimeRow(
              label: 'Final wake time',
              value: _finalWake,
              onTap: () => _pickTime('wake'),
            ),
            _TimeRow(
              label: 'Out of bed',
              value: _outOfBed,
              onTap: () => _pickTime('out'),
            ),
            if (_chronologyError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _chronologyError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 22),
            const Text('Night awakenings', style: _SleepText.section),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _awakenings,
                    label: 'Number of awakenings',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    controller: _awakeMinutes,
                    label: 'Total awake minutes',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Naps (optional)', style: _SleepText.section),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _napCount,
                    label: 'Number of naps',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    controller: _napMinutes,
                    label: 'Total nap minutes',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _RatingField(
              label: 'Morning restfulness',
              value: _restfulness,
              low: 'Not rested',
              high: 'Very rested',
              onChanged: (v) => setState(() => _restfulness = v),
            ),
            _RatingField(
              label: 'Daytime sleepiness',
              value: _sleepiness,
              low: 'Not sleepy',
              high: 'Very sleepy',
              onChanged: (v) => setState(() => _sleepiness = v),
            ),
            _RatingField(
              label: 'Perceived sleep quality',
              value: _quality,
              low: 'Very poor',
              high: 'Very good',
              onChanged: (v) => setState(() => _quality = v),
            ),
            ExpansionTile(
              title: const Text('Add how today felt (optional)'),
              initiallyExpanded: _showDaytime,
              onExpansionChanged: (value) =>
                  setState(() => _showDaytime = value),
              children: _showDaytime
                  ? [
                      _OptionalRatingField(
                        label: 'Energy',
                        value: _energy,
                        low: 'Very low',
                        high: 'Very high',
                        onChanged: (value) => setState(() => _energy = value),
                      ),
                      _OptionalRatingField(
                        label: 'Focus',
                        value: _focus,
                        low: 'Very difficult',
                        high: 'Very easy',
                        onChanged: (value) => setState(() => _focus = value),
                      ),
                    ]
                  : const [],
            ),
            const SizedBox(height: 14),
            const Text(
              'What may have contributed? (optional)',
              style: _SleepText.section,
            ),
            const SizedBox(height: 8),
            for (final group in SleepTags.groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  group.key,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: group.value
                    .where((key) => key != 'naps')
                    .map(
                      (key) => FilterChip(
                        label: Text(SleepTags.contributors[key]!),
                        selected: _contributors.contains(key),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _contributors.add(key)
                              : _contributors.remove(key),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 22),
            const Text('Safety check (optional)', style: _SleepText.section),
            const SizedBox(height: 4),
            const Text(
              'Select only what you noticed. Do not add medication details or private crisis disclosures here.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: SleepTags.concerns.entries
                  .map(
                    (entry) => FilterChip(
                      label: Text(entry.value),
                      selected: _concerns.contains(entry.key),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _concerns.add(entry.key)
                            : _concerns.remove(entry.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (_concerns.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MessageCard(
                error: true,
                message: _concerns.contains('dangerous_sleepiness')
                    ? 'Avoid driving or unsafe activities while dangerously sleepy. Consider prompt professional support.'
                    : 'These concerns are worth discussing with a healthcare professional or PACC support.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.services),
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: const Text('View support services'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                widget.entry == null ? 'Save sleep entry' : 'Save changes',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF2F6B5F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = SleepCalculator.manilaDate(DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: _wakeDate.isAfter(today) ? today : _wakeDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (value != null) setState(() => _wakeDate = value);
  }

  Future<void> _pickTime(String field) async {
    final current = switch (field) {
      'attempted' => _attempted,
      'onset' => _onset,
      'wake' => _finalWake,
      _ => _outOfBed,
    };
    final value = await showTimePicker(context: context, initialTime: current);
    if (value == null) return;
    setState(() {
      switch (field) {
        case 'attempted':
          _attempted = value;
        case 'onset':
          _onset = value;
        case 'wake':
          _finalWake = value;
        default:
          _outOfBed = value;
      }
      _chronologyError = null;
    });
  }

  int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final times = SleepCalculator.composeTimes(
      wakeDate: _wakeDate,
      attemptedMinutes: _minutes(_attempted),
      onsetMinutes: _minutes(_onset),
      finalWakeMinutes: _minutes(_finalWake),
      outOfBedMinutes: _minutes(_outOfBed),
    );
    if (times == null) {
      setState(
        () => _chronologyError =
            'These times cannot form a chronological sleep period of 24 hours or less.',
      );
      return;
    }
    final awakenings = int.parse(_awakenings.text);
    final awakeMinutes = awakenings == 0 ? 0 : int.parse(_awakeMinutes.text);
    if (awakenings > 0 && awakeMinutes <= 0) {
      setState(
        () => _chronologyError =
            'Add total awake minutes when awakenings are greater than zero.',
      );
      return;
    }
    final now = DateTime.now();
    final key = SleepEntry.wakeKey(_wakeDate);
    final entry = SleepEntry(
      id: SleepEntry.documentId(widget.userId, _wakeDate),
      userId: widget.userId,
      wakeDateKey: key,
      attemptedSleepAt: times[0],
      sleepOnsetAt: times[1],
      finalWakeAt: times[2],
      outOfBedAt: times[3],
      awakeningCount: awakenings,
      awakeMinutes: awakeMinutes,
      napCount: int.parse(_napCount.text),
      napMinutes: int.parse(_napMinutes.text),
      restfulness: _restfulness,
      daytimeSleepiness: _sleepiness,
      perceivedQuality: _quality,
      contributorTags: _contributors,
      concernTags: _concerns,
      createdAt: widget.entry?.createdAt ?? now,
      clientUpdatedAt: now,
      schemaVersion: SleepEntry.currentSchemaVersion,
      energy: _energy,
      focus: _focus,
      revision: widget.entry?.revision ?? 0,
    );
    final validation = SleepCalculator.validate(entry);
    if (validation != null) {
      setState(() => _chronologyError = validation);
      return;
    }
    final result = await context.read<SleepProvider>().save(entry);
    if (!mounted) return;
    if (result.localSaved) {
      Navigator.pop(context, true);
      return;
    }
    if (result.status == SleepSaveStatus.conflict &&
        result.conflictingEntry != null) {
      final resolved = await _resolveConflict(entry, result.conflictingEntry!);
      if (resolved && mounted) Navigator.pop(context, true);
      return;
    }
    setState(
      () => _chronologyError =
          result.message ?? 'We could not save this entry. Please try again.',
    );
  }

  Future<bool> _resolveConflict(SleepEntry local, SleepEntry cloud) async {
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entry changed on another device'),
        content: const Text(
          'Choose the version to keep. The cloud version is the version currently saved on the other device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep cloud version'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace with my version'),
          ),
        ],
      ),
    );
    if (replace == null) return false;
    if (!mounted) return false;
    final provider = context.read<SleepProvider>();
    if (!replace) {
      await provider.keepCloudConflict(cloud);
      return true;
    }
    return (await provider.replaceCloudConflict(local, cloud)).localSaved;
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.provider, required this.onRetry});
  final SleepProvider provider;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final pending =
        provider.syncState == SleepSyncState.pending ||
        provider.syncState == SleepSyncState.error;
    return _Card(
      child: Row(
        children: [
          Icon(
            provider.cloudEnabled
                ? Icons.cloud_done_outlined
                : Icons.phonelink_lock_outlined,
            color: const Color(0xFF2F6B5F),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.cloudEnabled
                  ? (pending
                        ? 'Saved locally · cloud sync pending'
                        : 'Encrypted locally · cloud sync on')
                  : 'Encrypted on this device only',
            ),
          ),
          if (pending)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _WellnessNotice extends StatelessWidget {
  const _WellnessNotice();
  @override
  Widget build(BuildContext context) => const _Card(
    color: Color(0xFFFFF4C7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'For general wellness only — estimates and patterns are not a diagnosis or medical score.',
          ),
        ),
      ],
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final SleepWindowSummary summary;
  @override
  Widget build(BuildContext context) {
    String duration(double? minutes) =>
        minutes == null ? '--' : '${(minutes / 60).toStringAsFixed(1)} h';
    String rating(double? value) =>
        value == null ? '--/5' : '${value.toStringAsFixed(1)}/5';
    final cards = [
      (
        'Recorded days',
        '${summary.entryCount}/${summary.windowDays}',
        Icons.nights_stay_outlined,
      ),
      (
        'Estimated sleep',
        duration(summary.averageSleepMinutes),
        Icons.bedtime_outlined,
      ),
      (
        'Efficiency',
        summary.averageEfficiency == null
            ? '--'
            : '${summary.averageEfficiency!.toStringAsFixed(0)}%',
        Icons.speed_outlined,
      ),
      ('Quality', rating(summary.averageQuality), Icons.star_outline),
      (
        'Restfulness',
        rating(summary.averageRestfulness),
        Icons.wb_sunny_outlined,
      ),
      (
        'Daytime sleepiness',
        rating(summary.averageSleepiness),
        Icons.battery_2_bar_outlined,
      ),
      (
        'Bedtime variation',
        summary.bedtimeVariationMinutes == null
            ? 'Not enough data'
            : '~${summary.bedtimeVariationMinutes!.round()} min',
        Icons.schedule_outlined,
      ),
      (
        'Night wakefulness',
        summary.averageWakefulnessMinutes == null
            ? '--'
            : '${summary.averageWakefulnessMinutes!.round()} min',
        Icons.visibility_outlined,
      ),
      if (summary.averageEnergy != null)
        ('Energy', rating(summary.averageEnergy), Icons.bolt_outlined),
      if (summary.averageFocus != null)
        (
          'Focus',
          rating(summary.averageFocus),
          Icons.center_focus_strong_outlined,
        ),
      if (summary.comparisonSleepMinutes != null)
        (
          'Recent sleep change',
          '${summary.comparisonSleepMinutes! >= 0 ? '+' : ''}${summary.comparisonSleepMinutes!.round()} min',
          Icons.compare_arrows_outlined,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$3, size: 21, color: const Color(0xFF2F6B5F)),
                        const SizedBox(height: 8),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });
  final SleepEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final measures = SleepCalculator.measures(entry);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE58A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${entry.perceivedQuality}/5',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(entry.wakeDateKey),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${(measures.totalSleepMinutes / 60).toStringAsFixed(1)} h estimated · ${measures.efficiency.toStringAsFixed(0)}% efficiency',
                  ),
                  if (entry.concernTags.isNotEmpty)
                    const Text(
                      'Safety guidance available',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiary extends StatelessWidget {
  const _EmptyDiary({required this.onLog});
  final VoidCallback onLog;
  @override
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          const Icon(Icons.bedtime_outlined, size: 44),
          const SizedBox(height: 10),
          const Text(
            'No sleep entries yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Log last night to begin seeing your own wellness patterns.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onLog,
            child: const Text("Log last night's sleep"),
          ),
        ],
      ),
    ),
  );
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();
  @override
  Widget build(BuildContext context) => _Card(
    color: const Color(0xFFFFE9E5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('When to seek support', style: _SleepText.section),
        const SizedBox(height: 6),
        const Text(
          'Talk with a healthcare professional about breathing pauses or gasping, loud snoring with tiredness, persistent or worsening problems, or severe daytime sleepiness. If sleepiness makes an activity unsafe, stop that activity and seek prompt help.',
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, RouteNames.services),
          icon: const Icon(Icons.support_agent_outlined),
          label: const Text('Open PACC support services'),
        ),
      ],
    ),
  );
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.schedule),
      label: Text(value.format(context)),
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      final number = int.tryParse(value ?? '');
      if (number == null || number < 0) return 'Enter 0 or more';
      return null;
    },
  );
}

class _RatingField extends StatelessWidget {
  const _RatingField({
    required this.label,
    required this.value,
    required this.low,
    required this.high,
    required this.onChanged,
  });
  final String label;
  final int value;
  final String low;
  final String high;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $value/5',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(low), Text(high)],
        ),
      ],
    ),
  );
}

class _OptionalRatingField extends StatelessWidget {
  const _OptionalRatingField({
    required this.label,
    required this.value,
    required this.low,
    required this.high,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final String low;
  final String high;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label${value == null ? '' : ': $value/5'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (value != null)
              TextButton(
                onPressed: () => onChanged(null),
                child: const Text('Clear'),
              ),
          ],
        ),
        Slider(
          value: (value ?? 3).toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '${value ?? 3}',
          onChanged: (rating) => onChanged(rating.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(low), Text(high)],
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x225F5035)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => _Card(
    color: error ? const Color(0xFFFFE9E5) : const Color(0xFFEAF5F1),
    child: Text(message),
  );
}

class _SleepText {
  const _SleepText._();
  static const section = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: Color(0xFF2E2820),
  );
}

String _formatDate(String key) => _dateLabel(SleepEntry.dateFromWakeKey(key));
String _dateLabel(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
