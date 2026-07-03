import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../../providers/breathing_provider.dart';
import '../../../providers/user_provider.dart';
import '../models/breathing_models.dart';

class MindfulBreathingScreen extends StatefulWidget {
  const MindfulBreathingScreen({super.key});

  @override
  State<MindfulBreathingScreen> createState() => _MindfulBreathingScreenState();
}

class _MindfulBreathingScreenState extends State<MindfulBreathingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _cuePlayer = AudioPlayer();
  BreathingTechnique? _activeTechnique;
  Timer? _timer;
  DateTime? _startedAt;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _soundEnabled = true;
  double _volume = .45;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
    _prepareAudio();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _musicPlayer.dispose();
    _cuePlayer.dispose();
    super.dispose();
  }

  Future<void> _prepareAudio() async {
    try {
      await _musicPlayer.setAsset('assets/audio/breathing/ambient_calm.mp3');
      await _musicPlayer.setLoopMode(LoopMode.one);
      await _musicPlayer.setVolume(_volume);
    } catch (_) {
      // Audio assets are optional during development.
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeTechnique;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F3DE),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _isCompleted && active != null
              ? _CompletionView(
                  technique: active,
                  isSaving: context.watch<BreathingProvider>().isSaving,
                  onDone: () => Navigator.of(context).pop(),
                  onRestart: () => _startSession(active),
                )
              : active == null
              ? _TechniquePicker(onStart: _startSession)
              : _BreathingPlayer(
                  technique: active,
                  elapsedSeconds: _elapsedSeconds,
                  isPaused: _isPaused,
                  soundEnabled: _soundEnabled,
                  volume: _volume,
                  pulseAnimation: _pulseController,
                  onTogglePause: _togglePause,
                  onRestart: () => _startSession(active),
                  onExit: _confirmExit,
                  onToggleSound: _toggleSound,
                  onVolumeChanged: _setVolume,
                ),
        ),
      ),
    );
  }

  Future<void> _startSession(BreathingTechnique technique) async {
    _timer?.cancel();
    setState(() {
      _activeTechnique = technique;
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
      _isPaused = false;
      _isCompleted = false;
    });
    _pulseController.repeat(reverse: true);
    unawaited(_playMusicIfEnabled());
    unawaited(_playCue('soft_chime.mp3'));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    final technique = _activeTechnique;
    if (technique == null || _isPaused || _isCompleted) return;

    final next = _elapsedSeconds + 1;
    if (next >= technique.durationSeconds) {
      setState(() {
        _elapsedSeconds = technique.durationSeconds;
      });
      await _completeSession();
      return;
    }

    setState(() => _elapsedSeconds = next);
  }

  Future<void> _completeSession() async {
    final technique = _activeTechnique;
    final userId = context.read<UserProvider>().user?.id;
    final startedAt = _startedAt;
    if (technique == null || startedAt == null || _isCompleted) return;

    _timer?.cancel();
    setState(() {
      _isCompleted = true;
      _isPaused = false;
    });
    unawaited(_musicPlayer.pause());
    unawaited(_playCue('session_complete.mp3'));

    if (userId == null || userId.trim().isEmpty) return;
    await context.read<BreathingProvider>().completeSession(
      userId: userId,
      technique: technique,
      completedSeconds: technique.durationSeconds,
      startedAt: startedAt,
    );
  }

  Future<void> _togglePause() async {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _pulseController.stop();
      await _musicPlayer.pause();
    } else {
      _pulseController.repeat(reverse: true);
      unawaited(_playMusicIfEnabled());
    }
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Leave this session?'),
        content: const Text(
          'Your breathing session is recorded only when the timer completes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (shouldExit != true || !mounted) return;
    _timer?.cancel();
    await _musicPlayer.pause();
    setState(() {
      _activeTechnique = null;
      _elapsedSeconds = 0;
      _isPaused = false;
    });
  }

  Future<void> _toggleSound() async {
    setState(() => _soundEnabled = !_soundEnabled);
    if (_soundEnabled) {
      unawaited(_playMusicIfEnabled());
    } else {
      await _musicPlayer.pause();
    }
  }

  Future<void> _setVolume(double value) async {
    setState(() => _volume = value);
    try {
      await _musicPlayer.setVolume(value);
    } catch (_) {}
  }

  Future<void> _playMusicIfEnabled() async {
    if (!_soundEnabled) return;
    try {
      await _musicPlayer.setVolume(_volume);
      await _musicPlayer.play();
    } catch (_) {}
  }

  Future<void> _playCue(String fileName) async {
    if (!_soundEnabled) return;
    try {
      await _cuePlayer.setAsset('assets/audio/breathing/$fileName');
      await _cuePlayer.play();
    } catch (_) {}
  }
}

class _TechniquePicker extends StatelessWidget {
  const _TechniquePicker({required this.onStart});

  final ValueChanged<BreathingTechnique> onStart;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Mindful Breathing',
                  style: TextStyle(
                    color: Color(0xFF1D2433),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a session. Start with no-hold breathing, then try hold techniques when your body feels comfortable.',
                  style: TextStyle(
                    color: Color(0xFF526071),
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          sliver: SliverList.separated(
            itemCount: BreathingPlan.techniques.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final technique = BreathingPlan.techniques[index];
              return _TechniqueCard(
                technique: technique,
                isRecommended: !technique.hasBreathHold && index < 3,
                onStart: () => onStart(technique),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  const _TechniqueCard({
    required this.technique,
    required this.isRecommended,
    required this.onStart,
  });

  final BreathingTechnique technique;
  final bool isRecommended;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onStart,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFCF3E), width: 1.1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1B8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      technique.durationLabel,
                      style: const TextStyle(
                        color: Color(0xFF1D2433),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isRecommended) const _SmallBadge(label: 'Beginner-safe'),
                  if (technique.hasBreathHold)
                    const _SmallBadge(label: 'Gentle holds'),
                  const Spacer(),
                  IconButton.filled(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    tooltip: 'Start session',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                technique.title,
                style: const TextStyle(
                  color: Color(0xFF1D2433),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                technique.bestFor,
                style: const TextStyle(
                  color: Color(0xFF2F6B5B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                technique.howTo,
                style: const TextStyle(
                  color: Color(0xFF526071),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (technique.hasBreathHold) ...[
                const SizedBox(height: 10),
                const Text(
                  'Use breath holds gently. Shorten the count or switch sessions if it feels uncomfortable.',
                  style: TextStyle(
                    color: Color(0xFF8A4B00),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1D6B50),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BreathingPlayer extends StatelessWidget {
  const _BreathingPlayer({
    required this.technique,
    required this.elapsedSeconds,
    required this.isPaused,
    required this.soundEnabled,
    required this.volume,
    required this.pulseAnimation,
    required this.onTogglePause,
    required this.onRestart,
    required this.onExit,
    required this.onToggleSound,
    required this.onVolumeChanged,
  });

  final BreathingTechnique technique;
  final int elapsedSeconds;
  final bool isPaused;
  final bool soundEnabled;
  final double volume;
  final Animation<double> pulseAnimation;
  final VoidCallback onTogglePause;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback onToggleSound;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final remaining = technique.durationSeconds - elapsedSeconds;
    final progress = elapsedSeconds / technique.durationSeconds;
    final phase = BreathingPlan.phaseFor(technique, elapsedSeconds);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onExit,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Exit session',
              ),
              const Spacer(),
              Text(
                technique.durationLabel,
                style: const TextStyle(
                  color: Color(0xFF526071),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            technique.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1D2433),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  final scale = .82 + (pulseAnimation.value * .18);
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: math.min(MediaQuery.sizeOf(context).width * .68, 260),
                  height: math.min(MediaQuery.sizeOf(context).width * .68, 260),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFE58F),
                        Color(0xFF7AD7BC),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x332F6B5B),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          phase.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1D2433),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${phase.remainingStepSeconds}',
                          style: const TextStyle(
                            color: Color(0xFF1D2433),
                            fontSize: 46,
                            height: .95,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            phase.guidance,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF526071),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white,
            color: const Color(0xFF2F6B5B),
          ),
          const SizedBox(height: 10),
          Text(
            _formatTime(remaining),
            style: const TextStyle(
              color: Color(0xFF1D2433),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: onRestart,
                icon: const Icon(Icons.replay_rounded),
                tooltip: 'Restart',
              ),
              const SizedBox(width: 14),
              IconButton.filled(
                onPressed: onTogglePause,
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                tooltip: isPaused ? 'Resume' : 'Pause',
                iconSize: 34,
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                onPressed: onToggleSound,
                icon: Icon(
                  soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                ),
                tooltip: soundEnabled ? 'Mute sound' : 'Enable sound',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.music_note_rounded, size: 18),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: soundEnabled ? onVolumeChanged : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTime(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final remainder = safe % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.technique,
    required this.isSaving,
    required this.onDone,
    required this.onRestart,
  });

  final BreathingTechnique technique;
  final bool isSaving;
  final VoidCallback onDone;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.self_improvement_rounded,
                size: 54,
                color: Color(0xFF2F6B5B),
              ),
              const SizedBox(height: 14),
              const Text(
                'Session complete',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1D2433),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${technique.title} • ${technique.durationLabel}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF526071),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Notice one thing that feels softer now. Your body may need a few quiet seconds before moving on.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF526071),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              if (isSaving) const LinearProgressIndicator(minHeight: 4),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDone,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
