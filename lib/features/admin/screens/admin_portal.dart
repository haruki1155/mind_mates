import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/admin_inquiry_model.dart';
import '../../../models/admin_activity_analytics_model.dart';
import '../../../models/admin_mind_aid_analytics_model.dart';
import '../../../models/appointment_model.dart';
import '../../../models/user_model.dart';
import '../../../models/profile_roles.dart';
import '../domain/admin_auth_failure.dart';
import '../domain/admin_management_models.dart';
import '../../../repositories/admin_portal_repository.dart';
import '../../../services/firebase/firebase_error_message.dart';
import '../../../services/firebase/firebase_runtime_diagnostics.dart';
import 'admin_status_dashboard_screen.dart';
import 'staff_registration_screen.dart';
import 'user_management_page.dart';
import 'admin_change_password_screen.dart';
import '../domain/admin_colors.dart';
import 'service_monitoring_page.dart';

const _yellow = AdminColors.primary;
const _orange = AdminColors.primaryPressed;
const _cream = AdminColors.background;
const _purple = AdminColors.info;
const _softAmber = AdminColors.softSurface;
const _success = AdminColors.success;
const _error = AdminColors.error;
const _adminBuildId = String.fromEnvironment(
  'ADMIN_BUILD_ID',
  defaultValue: 'development',
);

enum AdminPortalPage {
  dashboard,
  services,
  users,
  appointments,
  inquiries,
  assessments,
  sleepSummaries,
  profile,
  status,
}

extension on AdminPortalPage {
  String get label => switch (this) {
    AdminPortalPage.dashboard => 'Dashboard',
    AdminPortalPage.services => 'Service Monitoring',
    AdminPortalPage.users => 'User Management',
    AdminPortalPage.appointments => 'Appointments',
    AdminPortalPage.inquiries => 'Inquiries',
    AdminPortalPage.assessments => 'Assessments',
    AdminPortalPage.sleepSummaries => 'Shared Sleep Summaries',
    AdminPortalPage.profile => 'Profile',
    AdminPortalPage.status => 'Admin Status',
  };

  IconData get icon => switch (this) {
    AdminPortalPage.dashboard => Icons.home_outlined,
    AdminPortalPage.services => Icons.monitor_heart_outlined,
    AdminPortalPage.users => Icons.group_outlined,
    AdminPortalPage.appointments => Icons.calendar_month_outlined,
    AdminPortalPage.inquiries => Icons.chat_bubble_outline_rounded,
    AdminPortalPage.assessments => Icons.assignment_outlined,
    AdminPortalPage.sleepSummaries => Icons.bedtime_outlined,
    AdminPortalPage.profile => Icons.account_circle_outlined,
    AdminPortalPage.status => Icons.monitor_heart_outlined,
  };
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, this.repository});
  final AdminPortalRepository? repository;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _schoolId = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _schoolId.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_schoolId.text.trim().isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your School ID and password.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final repository = widget.repository ?? AdminPortalRepository();
      await repository.signInStaff(
        schoolId: _schoolId.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => repository.mustChangePassword
              ? AdminChangePasswordScreen(repository: repository)
              : AdminPortalHome(repository: repository),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is AdminAuthenticationException
          ? error.userMessage
          : 'Unable to sign in to the Admin portal. Try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AdminColors.background,
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 375),
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/Login/logo.png',
                    height: 72,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.psychology_alt_rounded,
                      color: _yellow,
                      size: 62,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'MindMate',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Counseling Management System',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AdminColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 34),
                  _LoginField(
                    label: 'Email',
                    hint: 'Enter your email address',
                    controller: _schoolId,
                  ),
                  const SizedBox(height: 14),
                  _LoginField(
                    label: 'Password',
                    hint: 'Enter your password',
                    obscure: true,
                    controller: _password,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _signIn,
                      child: Text(
                        _submitting ? 'Signing in...' : 'Sign in',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _submitting ? null : _resetPassword,
                    child: const Text('Forgot password?'),
                  ),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StaffRegistrationScreen(
                                repository:
                                    widget.repository ??
                                    AdminPortalRepository(),
                              ),
                            ),
                          ),
                    child: const Text('Register Staff Account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _resetPassword() async {
    if (_schoolId.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }
    try {
      await (widget.repository ?? AdminPortalRepository()).sendPasswordReset(
        _schoolId.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If that administrator account exists, Firebase sent a password reset email.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to request a password reset. Check the connection and try again.',
            ),
          ),
        );
      }
    }
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
    ],
  );
}

class AdminPortalHome extends StatefulWidget {
  const AdminPortalHome({super.key, this.repository});
  final AdminPortalRepository? repository;
  @override
  State<AdminPortalHome> createState() => _AdminPortalHomeState();
}

class _AdminPortalHomeState extends State<AdminPortalHome> {
  late final AdminPortalRepository _repository =
      widget.repository ?? AdminPortalRepository();
  AdminPortalPage _page = AdminPortalPage.dashboard;
  @override
  void initState() {
    super.initState();
    if (_repository.currentAccessRole == AccessRole.portalStaff) {
      _page = AdminPortalPage.users;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 840;
      return Scaffold(
        backgroundColor: _cream,
        drawer: compact
            ? Drawer(
                child: _Nav(
                  page: _page,
                  onChanged: _setPage,
                  compact: true,
                  accessRole: _repository.currentAccessRole,
                  isSuperAdmin: _repository.isSuperAdmin,
                ),
              )
            : null,
        body: Row(
          children: [
            if (!compact)
              SizedBox(
                width: 220,
                child: _Nav(
                  page: _page,
                  onChanged: _setPage,
                  accessRole: _repository.currentAccessRole,
                  isSuperAdmin: _repository.isSuperAdmin,
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(height: 4, color: _yellow),
                  _PortalHeader(
                    compact: compact,
                    page: _page,
                    repository: _repository,
                  ),
                  Expanded(child: _buildPage()),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  void _setPage(AdminPortalPage page) {
    Navigator.of(context).maybePop();
    setState(() => _page = page);
  }

  Widget _buildPage() => switch (_page) {
    AdminPortalPage.dashboard => _DashboardPage(repository: _repository),
    AdminPortalPage.services => ServiceMonitoringPage(repository: _repository),
    AdminPortalPage.users => UserManagementPage(repository: _repository),
    AdminPortalPage.appointments => _AppointmentsPage(repository: _repository),
    AdminPortalPage.inquiries => _InquiriesPage(repository: _repository),
    AdminPortalPage.assessments => _AssessmentsPage(repository: _repository),
    AdminPortalPage.sleepSummaries => _SleepSummariesPage(
      repository: _repository,
    ),
    AdminPortalPage.profile => _ProfilePage(repository: _repository),
    AdminPortalPage.status => const AdminStatusDashboardScreen(embedded: true),
  };
}

class _Nav extends StatelessWidget {
  const _Nav({
    required this.page,
    required this.onChanged,
    this.compact = false,
    this.accessRole = AccessRole.admin,
    this.isSuperAdmin = false,
  });
  final AdminPortalPage page;
  final ValueChanged<AdminPortalPage> onChanged;
  final bool compact;
  final AccessRole accessRole;
  final bool isSuperAdmin;

  bool _allowed(AdminPortalPage page) => switch (page) {
    _ when accessRole == AccessRole.portalStaff =>
      page == AdminPortalPage.users || page == AdminPortalPage.appointments,
    AdminPortalPage.users => accessRole.canUsePortal,
    AdminPortalPage.dashboard =>
      accessRole == AccessRole.counselor || accessRole == AccessRole.admin,
    AdminPortalPage.services =>
      accessRole == AccessRole.counselor || accessRole == AccessRole.admin,
    AdminPortalPage.sleepSummaries => accessRole == AccessRole.counselor,
    AdminPortalPage.assessments ||
    AdminPortalPage.status => accessRole.canAccessClinicalData,
    _ => accessRole.canUsePortal || accessRole == AccessRole.admin,
  };
  @override
  Widget build(BuildContext context) => Material(
    color: _yellow,
    child: SafeArea(
      child: Column(
        children: [
          if (compact)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                'MindMate Admin',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          const SizedBox(height: 24),
          for (final item in AdminPortalPage.values.where(_allowed))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: ListTile(
                dense: true,
                leading: Icon(
                  item.icon,
                  color: page == item ? Colors.white : Colors.black,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: page == item ? Colors.white : Colors.black,
                    fontSize: 13,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                selected: page == item,
                selectedTileColor: _orange,
                onTap: () => onChanged(item),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SleepSummariesPage extends StatelessWidget {
  const _SleepSummariesPage({required this.repository});
  final AdminPortalRepository repository;

  @override
  Widget build(BuildContext context) {
    final counselorId = FirebaseAuth.instance.currentUser?.uid;
    if (counselorId == null) {
      return const Center(
        child: Text('Sign in to view shared sleep summaries.'),
      );
    }
    return StreamBuilder<List<CounselorSleepSummaryRecord>>(
      stream: repository.watchCounselorSleepSummaries(counselorId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Shared sleep summaries are unavailable.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final summaries = snapshot.data!;
        if (summaries.isEmpty) {
          return const Center(
            child: Text('No active sleep summaries have been shared with you.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Shared Sleep Summaries',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _manageAssignment(context, counselorId),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Manage assignment'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Self-reported wellness information. It is not diagnostic and is available only while the user’s sharing permission remains active.',
            ),
            const SizedBox(height: 16),
            for (final summary in summaries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.loggedDays}/${summary.windowDays} days recorded',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Estimated sleep: ${summary.averageSleepMinutes == null ? 'Not enough entries' : '${(summary.averageSleepMinutes! / 60).toStringAsFixed(1)} h'}',
                      ),
                      Text(
                        'Sleep quality: ${summary.averageQuality?.toStringAsFixed(1) ?? '--'}/5',
                      ),
                      Text(
                        'Daytime sleepiness: ${summary.averageSleepiness?.toStringAsFixed(1) ?? '--'}/5',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _discussionPrompt(summary),
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      if (summary.guidanceShown['dangerousSleepiness'] ==
                              true ||
                          summary.guidanceShown['breathingConcern'] ==
                              true) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'The user reported a safety-related sleep observation and was shown guidance to consider appropriate professional support.',
                          style: TextStyle(color: Colors.deepOrange),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _discussionPrompt(CounselorSleepSummaryRecord summary) {
    if ((summary.averageSleepiness ?? 0) >= 3.5) {
      return 'Discussion prompt: You reported more daytime sleepiness during this period. How has that affected classes or daily activities?';
    }
    if ((summary.averageSleepMinutes ?? 999) < 7 * 60) {
      return 'Discussion prompt: Your recent entries describe shorter estimated sleep. What was happening with your routine during this period?';
    }
    return 'Discussion prompt: How has your current routine affected the sleep pattern you recorded during this period?';
  }

  Future<void> _manageAssignment(
    BuildContext context,
    String counselorId,
  ) async {
    final controller = TextEditingController();
    final active = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Counselor assignment'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Student account ID',
            helperText: 'A confirmed appointment is required to start access.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('End assignment'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start assignment'),
          ),
        ],
      ),
    );
    final studentId = controller.text.trim();
    controller.dispose();
    if (active == null || studentId.isEmpty || !context.mounted) return;
    try {
      await repository.setCounselorSleepAssignment(
        studentId: studentId,
        counselorId: counselorId,
        active: active,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'Counselor assignment started.'
                  : 'Counselor assignment ended.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update the counselor assignment.'),
          ),
        );
      }
    }
  }
}

class _PortalHeader extends StatelessWidget {
  const _PortalHeader({
    required this.compact,
    required this.page,
    required this.repository,
  });
  final bool compact;
  final AdminPortalPage page;
  final AdminPortalRepository repository;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 28, 12),
    child: Row(
      children: [
        if (compact)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              repository.currentAuthUser?.displayName?.trim().isNotEmpty == true
                  ? repository.currentAuthUser!.displayName!
                  : repository.currentAuthUser?.email ?? 'Staff member',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  repository.currentAccessRole.storedValue,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(width: 6),
                _Tag(
                  label: repository.currentAccessRole == AccessRole.admin
                      ? 'Admin'
                      : 'Staff',
                  color: _yellow,
                ),
              ],
            ),
            Text(
              'Build $_adminBuildId',
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ],
        ),
        const SizedBox(width: 12),
        const CircleAvatar(
          backgroundColor: _yellow,
          child: Icon(Icons.account_circle, color: Colors.white, size: 32),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: () async {
            await repository.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => AdminLoginScreen(repository: repository),
                ),
                (_) => false,
              );
            }
          },
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AdminColors.textMuted),
        ),
        const SizedBox(height: 24),
        child,
      ],
    ),
  );
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({required this.repository});
  final AdminPortalRepository repository;
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Analytics Dashboard',
    subtitle: 'Overview of System usage and statistics',
    child: FutureBuilder<AdminDashboardSummary>(
      future: repository.getAppUserDashboardSummary(),
      builder: (context, summarySnapshot) => StreamBuilder<List<AdminInquiryModel>>(
        stream: repository.watchInquiries(),
        builder: (context, inquiries) => StreamBuilder<List<AdminAssessmentRecord>>(
          stream: repository.watchAssessments(),
          builder: (context, assessments) {
            if (summarySnapshot.hasError ||
                inquiries.hasError ||
                assessments.hasError) {
              return const _AccessPanel();
            }
            if (!summarySnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final summary = summarySnapshot.data!;
            final inquiryList = inquiries.data ?? const <AdminInquiryModel>[];
            final assessmentList =
                assessments.data ?? const <AdminAssessmentRecord>[];
            final studentCount = summary.populationCounts['student'] ?? 0;
            return Column(
              children: [
                LayoutBuilder(
                  builder: (context, box) => Wrap(
                    spacing: 18,
                    runSpacing: 14,
                    children: [
                      _StatCard(
                        label: 'Total App Users',
                        value: '${summary.totalAppUsers}',
                        note: '$studentCount students',
                        icon: Icons.groups_outlined,
                        color: _softAmber,
                      ),
                      _StatCard(
                        label: 'Total Inquiries',
                        value: '${inquiryList.length}',
                        note:
                            '${inquiryList.where((i) => i.status == InquiryStatus.pending).length} Pending',
                        icon: Icons.chat_bubble_outline,
                        color: const Color(0xFFC1BFFF),
                      ),
                      _StatCard(
                        label: 'Assessments',
                        value: '${assessmentList.length}',
                        note:
                            '${assessmentList.where((a) => a.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length} this week',
                        icon: Icons.assignment_outlined,
                        color: _success.withValues(alpha: .18),
                      ),
                      _StatCard(
                        label: 'Engagement Rate',
                        value: summary.totalAppUsers == 0
                            ? '0%'
                            : '${((summary.activeAppUsers / summary.totalAppUsers) * 100).round()}%',
                        note: 'App users with activity',
                        icon: Icons.trending_up,
                        color: const Color(0xFFFFE8A5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SummaryRow(
                  values: {
                    'Portal Staff': summary.portalCounts['portalStaff'] ?? 0,
                    'Counselors': summary.portalCounts['counselor'] ?? 0,
                    'Administrators': summary.portalCounts['admin'] ?? 0,
                  },
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, box) => Wrap(
                    spacing: 24,
                    runSpacing: 18,
                    children: [
                      SizedBox(
                        width: box.maxWidth > 900
                            ? (box.maxWidth - 24) / 2
                            : box.maxWidth,
                        child: _ChartCard(
                          title: 'Monthly App Activity',
                          child: _ActivityChart(
                            values: summary.monthlyActiveUsers,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: box.maxWidth > 900
                            ? (box.maxWidth - 24) / 2
                            : box.maxWidth,
                        child: _ChartCard(
                          title: 'User Distribution',
                          child: _DistributionChart(
                            counts: summary.populationCounts,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _ChartCard(
                  title: 'Inquiries by Category',
                  child: _CategoryChart(items: inquiryList),
                ),
                const SizedBox(height: 18),
                _LiveActivityPanel(repository: repository),
                const SizedBox(height: 18),
                _MindAidQualityPanel(repository: repository),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _MindAidQualityPanel extends StatelessWidget {
  const _MindAidQualityPanel({required this.repository});

  final AdminPortalRepository repository;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<AdminMindAidAnalyticsModel>>(
    stream: repository.watchMindAidAnalytics(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const _AccessPanel();
      final entries = (snapshot.data ?? const [])
          .where((entry) {
            final date = DateTime.tryParse(entry.dateKey);
            return date != null &&
                date.isAfter(DateTime.now().subtract(const Duration(days: 8)));
          })
          .toList(growable: false);
      final turns = entries.fold<int>(0, (sum, entry) => sum + entry.turnCount);
      final fallbacks = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.fallbackCount,
      );
      final latency = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.latencyTotalMs,
      );
      final helpful = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.helpfulCount,
      );
      final unhelpful = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.unhelpfulCount,
      );
      final intents = <String, int>{};
      final safety = <String, int>{};
      for (final entry in entries) {
        entry.intentCounts.forEach(
          (key, value) => intents[key] = (intents[key] ?? 0) + value,
        );
        entry.safetyCounts.forEach(
          (key, value) => safety[key] = (safety[key] ?? 0) + value,
        );
      }
      final sortedIntents = intents.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: _box,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MindAid Quality — Last 7 Days',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aggregate operational metrics only. Conversation text is never shown.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Tag(label: '$turns turns', color: _softAmber),
                _Tag(
                  label: '$fallbacks fallbacks',
                  color: _success.withValues(alpha: .18),
                ),
                _Tag(
                  label: turns == 0
                      ? 'No latency data'
                      : '${(latency / turns).round()} ms average',
                  color: AdminColors.info.withValues(alpha: .18),
                ),
                _Tag(
                  label: '$helpful helpful / $unhelpful needs improvement',
                  color: _success.withValues(alpha: .12),
                ),
                if ((safety['crisisOrImmediateRisk'] ?? 0) > 0)
                  _Tag(
                    label:
                        '${safety['crisisOrImmediateRisk']} crisis intercepts',
                    color: _error.withValues(alpha: .16),
                  ),
              ],
            ),
            if (sortedIntents.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedIntents
                    .take(8)
                    .map(
                      (entry) => _Tag(
                        label: '${entry.key}: ${entry.value}',
                        color: _softAmber,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _LiveActivityPanel extends StatefulWidget {
  const _LiveActivityPanel({required this.repository});
  final AdminPortalRepository repository;

  @override
  State<_LiveActivityPanel> createState() => _LiveActivityPanelState();
}

class _LiveActivityPanelState extends State<_LiveActivityPanel> {
  int days = 7;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<AdminActivityAnalyticsModel>>(
    stream: widget.repository.watchActivityAnalytics(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const _AccessPanel();
      final cutoff = DateTime.now().subtract(Duration(days: days - 1));
      final entries = (snapshot.data ?? const <AdminActivityAnalyticsModel>[])
          .where(
            (entry) =>
                DateTime.tryParse(
                  entry.dateKey,
                )?.isAfter(cutoff.subtract(const Duration(days: 1))) ??
                false,
          )
          .toList();
      final activeUsers = entries.fold(
        0,
        (sum, entry) => sum + entry.activeUserCount,
      );
      final events = entries.fold(0, (sum, entry) => sum + entry.eventCount);
      final types = <String, int>{};
      for (final entry in entries) {
        entry.activityCounts.forEach(
          (type, count) => types[type] = (types[type] ?? 0) + count,
        );
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: _box,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Live App Activity',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
                DropdownButton<int>(
                  value: days,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Today')),
                    DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                    DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                  ],
                  onChanged: (value) => setState(() => days = value!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$activeUsers daily active-user records • $events tracked events',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            if (types.isEmpty)
              const Text('Activity will appear after students use the app.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: types.entries
                    .map(
                      (entry) => _Tag(
                        label: '${entry.key}: ${entry.value}',
                        color: _softAmber,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      );
    },
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
  });
  final String label, value, note;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 260,
    padding: const EdgeInsets.all(22),
    decoration: _box,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                note,
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 31,
          backgroundColor: color,
          child: Icon(icon, color: _yellow, size: 32),
        ),
      ],
    ),
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    height: 310,
    padding: const EdgeInsets.all(20),
    decoration: _box,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 18),
        Expanded(child: child),
      ],
    ),
  );
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.values});
  final Map<String, int> values;
  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final points = entries.map((entry) => entry.value).toList();
    final max = points.fold(1, (a, b) => a > b ? a : b);
    return CustomPaint(
      painter: _LinePainter(points.map((v) => v / max).toList()),
      child: const SizedBox.expand(),
    );
  }
}

class _DistributionChart extends StatelessWidget {
  const _DistributionChart({required this.counts});
  final Map<String, int> counts;
  @override
  Widget build(BuildContext context) {
    final students = counts['student'] ?? 0;
    final teaching = counts['teaching'] ?? 0;
    final nonTeaching = counts['nonTeaching'] ?? 0;
    final total = students + teaching + nonTeaching + (counts['unknown'] ?? 0);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _PiePainter(total == 0 ? .0 : students / total),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Students: $students  •  Teaching: $teaching  •  Non-Teaching: $nonTeaching',
            style: const TextStyle(color: _yellow, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.items});
  final List<AdminInquiryModel> items;
  @override
  Widget build(BuildContext context) {
    final values = <String, int>{};
    for (final item in items) {
      values[item.category] = (values[item.category] ?? 0) + 1;
    }
    final entries = values.entries.take(5).toList();
    final max = entries.fold(1, (n, e) => n > e.value ? n : e.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        color: _yellow,
                        height: 210 * entry.value / max,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.key,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _UsersPage extends StatefulWidget {
  const _UsersPage({required this.repository});
  final AdminPortalRepository repository;
  @override
  State<_UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<_UsersPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => _Page(
    title: 'User Management',
    subtitle: 'Manage system users and staff accounts',
    child: StreamBuilder<List<UserModel>>(
      stream: widget.repository.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _AccessPanel();
        final users = (snapshot.data ?? const <UserModel>[])
            .where(
              (u) =>
                  (u.displayName.toLowerCase().contains(query.toLowerCase()) ||
                  u.email.toLowerCase().contains(query.toLowerCase())),
            )
            .toList();
        return Container(
          decoration: _box,
          child: Column(
            children: [
              if (widget.repository.currentAccessRole.canManageAccess)
                _OrganizationDirectoryPanel(repository: widget.repository),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search users...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _ResponsiveTable(
                columns: const [
                  'Name',
                  'Contact',
                  'Role',
                  'Account',
                  'Department',
                  'College / Course',
                  'Last Active',
                  'Join Date',
                  'Actions',
                ],
                rows: users
                    .map(
                      (u) => [
                        u.displayName,
                        u.email,
                        _Tag(label: u.roleLabel, color: _purple),
                        _Tag(
                          label: u.staffAccountStatus?.label ?? 'App user',
                          color:
                              u.staffAccountStatus ==
                                  StaffAccountStatus.approved
                              ? _success
                              : Colors.orange.shade200,
                        ),
                        u.departmentId ?? u.department ?? '—',
                        [u.collegeId, u.courseId]
                                .whereType<String>()
                                .where((e) => e.isNotEmpty)
                                .join(' / ')
                                .isEmpty
                            ? '—'
                            : [u.collegeId, u.courseId]
                                  .whereType<String>()
                                  .where((e) => e.isNotEmpty)
                                  .join(' / '),
                        _date(u.lastActiveAt),
                        _date(u.createdAt),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (u.staffAccountStatus ==
                                    StaffAccountStatus.pending &&
                                widget
                                    .repository
                                    .currentAccessRole
                                    .canManageAccess)
                              IconButton(
                                tooltip: 'Review staff registration',
                                onPressed: () => _reviewStaff(u),
                                icon: const Icon(
                                  Icons.how_to_reg,
                                  color: Colors.green,
                                ),
                              ),
                            if ((u.staffAccountStatus ==
                                        StaffAccountStatus.approved ||
                                    u.staffAccountStatus ==
                                        StaffAccountStatus.disabled) &&
                                widget
                                    .repository
                                    .currentAccessRole
                                    .canManageAccess)
                              IconButton(
                                tooltip:
                                    u.staffAccountStatus ==
                                        StaffAccountStatus.disabled
                                    ? 'Enable account'
                                    : 'Disable account',
                                onPressed: () => _toggleStaff(u),
                                icon: Icon(
                                  u.staffAccountStatus ==
                                          StaffAccountStatus.disabled
                                      ? Icons.lock_open
                                      : Icons.block,
                                  color: Colors.red,
                                ),
                              ),
                            if (widget
                                .repository
                                .currentAccessRole
                                .canManageAccess)
                              IconButton(
                                tooltip: 'Manage portal access',
                                onPressed: () => _manageAccess(u),
                                icon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                              ),
                            if (u.staffAccountStatus != null &&
                                widget
                                    .repository
                                    .currentAccessRole
                                    .canManageAccess)
                              IconButton(
                                tooltip: 'View audit history',
                                onPressed: () => _showAudit(u),
                                icon: const Icon(Icons.history),
                              ),
                          ],
                        ),
                      ],
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _manageAccess(UserModel user) async {
    var access = user.accessRole;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Access for ${user.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AccessRole>(
                initialValue: access,
                items:
                    const [
                          AccessRole.appUser,
                          AccessRole.portalStaff,
                          AccessRole.counselor,
                        ]
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.storedValue),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => access = value);
                },
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Change reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && reason.text.trim().length >= 3) {
      await widget.repository.assignAccessRole(
        userId: user.id,
        accessRole: access,
        reason: reason.text,
      );
    }
    reason.dispose();
  }

  Future<void> _reviewStaff(UserModel user) async {
    var role = AccessRole.portalStaff;
    var approve = true;
    final reason = TextEditingController(text: 'Staff registration reviewed');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Review ${user.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: approve,
                onChanged: (v) => setState(() => approve = v),
                title: Text(approve ? 'Approve' : 'Reject'),
              ),
              if (approve)
                DropdownButtonFormField<AccessRole>(
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(
                      value: AccessRole.portalStaff,
                      child: Text('Portal Staff'),
                    ),
                    DropdownMenuItem(
                      value: AccessRole.counselor,
                      child: Text('Counselor'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => role = v);
                  },
                ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await widget.repository.reviewStaffRegistration(
        userId: user.id,
        approve: approve,
        accessRole: role,
        reason: reason.text,
      );
    }
    reason.dispose();
  }

  Future<void> _toggleStaff(UserModel user) async {
    final enable = user.staffAccountStatus == StaffAccountStatus.disabled;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${enable ? 'Enable' : 'Disable'} ${user.displayName}?'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && reason.text.trim().length >= 3) {
      await widget.repository.setStaffAccountEnabled(
        userId: user.id,
        enabled: enable,
        reason: reason.text,
      );
    }
    reason.dispose();
  }

  Future<void> _showAudit(UserModel user) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Audit history — ${user.displayName}'),
      content: SizedBox(
        width: 560,
        child: StreamBuilder<List<AdminAuditEvent>>(
          stream: widget.repository.watchAdminAudit(user.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Unable to load audit history.');
            }
            final events = snapshot.data ?? const [];
            if (events.isEmpty) {
              return const Text('No privileged changes recorded.');
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: events.length,
              itemBuilder: (_, index) {
                final event = events[index];
                return ListTile(
                  title: Text(event.action),
                  subtitle: Text('${event.reason}\nActor: ${event.actorId}'),
                  trailing: Text(_date(event.createdAt)),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _OrganizationDirectoryPanel extends StatelessWidget {
  const _OrganizationDirectoryPanel({required this.repository});
  final AdminPortalRepository repository;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text(
      'Colleges, Departments & Courses',
      style: TextStyle(fontWeight: FontWeight.w800),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<College>>(
          stream: repository.watchColleges(),
          builder: (context, colleges) => StreamBuilder<List<Department>>(
            stream: repository.watchDepartments(),
            builder: (context, departments) => StreamBuilder<List<Course>>(
              stream: repository.watchCourses(),
              builder: (context, courses) => Column(
                children: [
                  _directoryRow(
                    context,
                    'college',
                    'Colleges',
                    colleges.data ?? const [],
                  ),
                  _directoryRow(
                    context,
                    'department',
                    'Departments',
                    departments.data ?? const [],
                  ),
                  _directoryRow(
                    context,
                    'course',
                    'Courses',
                    courses.data ?? const [],
                    colleges: colleges.data ?? const [],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _directoryRow(
    BuildContext context,
    String kind,
    String label,
    List<OrganizationRecord> records, {
    List<College> colleges = const [],
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListTile(
        title: Text(label),
        trailing: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _edit(context, kind, colleges),
        ),
      ),
      if (records.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('No records'),
        ),
      Wrap(
        spacing: 8,
        children: records
            .map(
              (record) => ActionChip(
                avatar: Icon(
                  record.active ? Icons.check_circle : Icons.pause_circle,
                  size: 18,
                ),
                label: Text('${record.code}: ${record.name}'),
                onPressed: () => _edit(context, kind, colleges, record: record),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 12),
    ],
  );

  Future<void> _edit(
    BuildContext context,
    String kind,
    List<College> colleges, {
    OrganizationRecord? record,
  }) async {
    final name = TextEditingController(text: record?.name);
    final code = TextEditingController(text: record?.code);
    String? collegeId = record is Course ? record.collegeId : null;
    var active = record?.active ?? true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${record == null ? 'Add' : 'Edit'} $kind'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              if (kind == 'course')
                DropdownButtonFormField<String>(
                  initialValue: collegeId,
                  decoration: const InputDecoration(labelText: 'College'),
                  items: colleges
                      .where((e) => e.active)
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => collegeId = v),
                ),
              SwitchListTile(
                value: active,
                onChanged: (v) => setState(() => active = v),
                title: const Text('Active'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true &&
        name.text.trim().length >= 2 &&
        code.text.trim().isNotEmpty &&
        (kind != 'course' || collegeId != null)) {
      await repository.saveOrganizationRecord(
        kind: kind,
        id: record?.id,
        name: name.text,
        code: code.text,
        active: active,
        collegeId: collegeId ?? '',
      );
    }
    name.dispose();
    code.dispose();
  }
}

class _AppointmentsPage extends StatefulWidget {
  const _AppointmentsPage({required this.repository});
  final AdminPortalRepository repository;
  @override
  State<_AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<_AppointmentsPage> {
  String filter = 'All status';
  int view = 0;
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Appointments',
    subtitle: 'Manage your counseling appointments',
    child: StreamBuilder<List<AppointmentModel>>(
      stream: widget.repository.watchAppointments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return const _AccessPanel();
        final all = snapshot.data ?? const <AppointmentModel>[];
        final active = all.where((a) => a.lifecycleStatus.isActive).toList();
        final archived = all
            .where(
              (a) =>
                  a.lifecycleStatus.isTerminal ||
                  a.lifecycleStatus == AppointmentLifecycleStatus.unknown,
            )
            .toList();
        final items = filter == 'All status'
            ? all
            : all
                  .where(
                    (a) =>
                        a.lifecycleStatus.storedValue == filter.toLowerCase(),
                  )
                  .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow(
              values: {
                'Active queue': active.length,
                'Pending': active
                    .where(
                      (a) =>
                          a.lifecycleStatus ==
                          AppointmentLifecycleStatus.pending,
                    )
                    .length,
                'Ongoing': active
                    .where(
                      (a) =>
                          a.lifecycleStatus ==
                          AppointmentLifecycleStatus.ongoing,
                    )
                    .length,
                'Archive': archived.length,
              },
            ),
            const SizedBox(height: 22),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.inbox_outlined),
                  label: Text('Active queue'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('Calendar'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.inventory_2_outlined),
                  label: Text('History / Archive'),
                ),
              ],
              selected: {view},
              onSelectionChanged: (values) =>
                  setState(() => view = values.first),
            ),
            const SizedBox(height: 18),
            if (view == 0) ...[
              _Filter(
                label: 'Filter:',
                value: filter,
                values: const [
                  'All status',
                  'pending',
                  'confirmed',
                  'ongoing',
                  'reschedule_proposed',
                ],
                onChanged: (v) => setState(() => filter = v!),
              ),
              const SizedBox(height: 22),
              if (!items.any((a) => a.lifecycleStatus.isActive))
                const _EmptyPanel(
                  message: 'No active appointments match this filter.',
                ),
              ...items
                  .where((a) => a.lifecycleStatus.isActive)
                  .map(
                    (a) => _AppointmentCard(
                      item: a,
                      repository: widget.repository,
                    ),
                  ),
            ] else if (view == 1)
              _AppointmentCalendar(items: active, repository: widget.repository)
            else ...[
              const Text(
                'Completed, declined, and cancelled appointments are retained in the archive.',
              ),
              const SizedBox(height: 12),
              if (archived.isEmpty)
                const _EmptyPanel(message: 'No archived appointments yet.'),
              ...archived.map(
                (a) => _AppointmentCard(item: a, repository: widget.repository),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item, required this.repository});
  final AppointmentModel item;
  final AdminPortalRepository repository;
  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.fullName,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            _Tag(label: item.course ?? 'User', color: AdminColors.highlight),
          ],
        ),
        const SizedBox(height: 5),
        Text(item.email, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 9),
        Text(item.concern),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          children: [
            _Tag(
              label: item.lifecycleStatus.label,
              color: _statusColor(item.lifecycleStatus.storedValue),
            ),
            Text(
              _date(item.scheduledAt),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              item.scheduledTime,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Location: ${item.location}'),
            Text('Requested: ${_dateTime(item.createdAt)}'),
            Text('Assignee: ${item.counselorName ?? 'Unassigned'}'),
            if (item.parentAppointmentId != null)
              Text('Follow-up of ${item.parentAppointmentId}'),
          ],
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: () => _showTimeline(context),
          icon: const Icon(Icons.history_outlined),
          label: const Text('Timeline'),
        ),
        ..._lifecycleActions(context),
        if (item.lifecycleStatus == AppointmentLifecycleStatus.completed)
          FilledButton.icon(
            onPressed: () => _showFollowUpDialog(context),
            icon: const Icon(Icons.event_repeat_outlined),
            label: const Text('Schedule follow-up'),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(compact ? 18 : 28),
          decoration: _box,
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 14), actions],
                )
              : Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    actions,
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _lifecycleActions(BuildContext context) =>
      switch (item.lifecycleStatus) {
        AppointmentLifecycleStatus.pending => [
          FilledButton.icon(
            onPressed: () => _showActionDialog(context, action: 'confirmed'),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirm'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                _showActionDialog(context, action: 'reschedule_proposed'),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Propose reschedule'),
          ),
          TextButton.icon(
            onPressed: () => _showActionDialog(context, action: 'declined'),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Decline'),
          ),
        ],
        AppointmentLifecycleStatus.confirmed => [
          FilledButton.icon(
            onPressed: () => _showActionDialog(context, action: 'ongoing'),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Start session'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                _showActionDialog(context, action: 'reschedule_proposed'),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Propose reschedule'),
          ),
          TextButton.icon(
            onPressed: () => _showActionDialog(context, action: 'declined'),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Decline'),
          ),
        ],
        AppointmentLifecycleStatus.ongoing => [
          FilledButton.icon(
            onPressed: () => _showActionDialog(context, action: 'completed'),
            icon: const Icon(Icons.task_alt_outlined),
            label: const Text('Complete session'),
          ),
        ],
        AppointmentLifecycleStatus.rescheduleProposed => [
          OutlinedButton.icon(
            onPressed: () =>
                _showActionDialog(context, action: 'reschedule_proposed'),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Replace proposal'),
          ),
          TextButton.icon(
            onPressed: () =>
                _showActionDialog(context, action: 'withdraw_reschedule'),
            icon: const Icon(Icons.undo_outlined),
            label: const Text('Withdraw proposal'),
          ),
        ],
        _ => const [],
      };

  Future<void> _showActionDialog(
    BuildContext context, {
    required String action,
  }) async {
    final reply = TextEditingController();
    final proposedTime = TextEditingController();
    DateTime? proposedDate;
    final operationId = AdminPortalRepository.newOperationId();
    var saving = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('${_actionTitle(action)}: ${item.fullName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reply,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Reply to student',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (action == 'reschedule_proposed') ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => proposedDate = picked);
                      }
                    },
                    child: Text(
                      proposedDate == null
                          ? 'Choose proposed date'
                          : _date(proposedDate),
                    ),
                  ),
                  TextField(
                    controller: proposedTime,
                    decoration: const InputDecoration(
                      labelText: 'Proposed time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (reply.text.trim().isEmpty ||
                          (action == 'reschedule_proposed' &&
                              (proposedDate == null ||
                                  proposedTime.text.trim().isEmpty))) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a reply and all proposed time details.',
                            ),
                          ),
                        );
                        return;
                      }
                      try {
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        await repository.reviewAppointment(
                          appointmentId: item.id,
                          action: action,
                          reply: reply.text.trim(),
                          proposedScheduledAt: proposedDate,
                          proposedScheduledTime: proposedTime.text.trim(),
                          operationId: operationId,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            saveError = _appointmentError(error);
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : _actionTitle(action)),
            ),
            if (saveError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  saveError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
    reply.dispose();
    proposedTime.dispose();
  }

  String _actionTitle(String action) => switch (action) {
    'confirmed' => 'Confirm appointment',
    'ongoing' => 'Start session',
    'completed' => 'Complete session',
    'declined' => 'Decline appointment',
    'reschedule_proposed' => 'Propose reschedule',
    'withdraw_reschedule' => 'Withdraw proposal',
    _ => 'Update appointment',
  };

  Future<void> _showTimeline(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Appointment timeline'),
      content: SizedBox(
        width: 500,
        child: StreamBuilder<List<AppointmentHistoryEvent>>(
          stream: repository.watchAppointmentHistory(item.id),
          builder: (context, snapshot) {
            final events = snapshot.data ?? const <AppointmentHistoryEvent>[];
            return ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Requested: ${_date(item.createdAt)}\nScheduled session: ${_date(item.scheduledAt)} ${item.scheduledTime}\nCurrent status: ${item.lifecycleStatus.label}',
                ),
                const Divider(),
                if (events.isEmpty) const Text('No recorded changes yet.'),
                ...events.map(
                  (event) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(event.eventType.replaceAll('_', ' ')),
                    subtitle: Text(
                      [
                        if (event.actorName != null) event.actorName!,
                        if (event.previousStatus != null)
                          '${event.previousStatus} → ${event.status}',
                        if (event.createdAt != null)
                          _dateTime(event.createdAt!),
                        if (event.reply.isNotEmpty) event.reply,
                        if (event.proposedScheduledAt != null)
                          'Proposed: ${_dateTime(event.proposedScheduledAt!)} ${event.proposedScheduledTime ?? ''}',
                        if (event.linkedAppointmentId != null)
                          'Linked: ${event.linkedAppointmentId}',
                      ].join('\n'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _showFollowUpDialog(BuildContext context) async {
    final time = TextEditingController();
    final location = TextEditingController(text: item.location);
    final reply = TextEditingController();
    DateTime? date;
    var saving = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Schedule follow-up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: Text(date == null ? 'Choose session date' : _date(date)),
              ),
              TextField(
                controller: time,
                decoration: const InputDecoration(labelText: 'Scheduled time'),
              ),
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              TextField(
                controller: reply,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message to app user',
                ),
              ),
              if (saveError != null)
                Text(
                  saveError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (saving ||
                    date == null ||
                    time.text.trim().isEmpty ||
                    location.text.trim().isEmpty ||
                    reply.text.trim().isEmpty) {
                  return;
                }
                setDialogState(() {
                  saving = true;
                  saveError = null;
                });
                try {
                  await repository.scheduleAppointmentFollowUp(
                    sourceAppointmentId: item.id,
                    scheduledAt: date!,
                    scheduledTime: time.text,
                    location: location.text,
                    reply: reply.text,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      saving = false;
                      saveError = _appointmentError(error);
                    });
                  }
                }
              },
              child: Text(saving ? 'Creating…' : 'Create follow-up'),
            ),
          ],
        ),
      ),
    );
    time.dispose();
    location.dispose();
    reply.dispose();
  }
}

class _AppointmentCalendar extends StatefulWidget {
  const _AppointmentCalendar({required this.items, required this.repository});
  final List<AppointmentModel> items;
  final AdminPortalRepository repository;
  @override
  State<_AppointmentCalendar> createState() => _AppointmentCalendarState();
}

class _AppointmentCalendarState extends State<_AppointmentCalendar> {
  late DateTime selectedDate = widget.items.isEmpty
      ? DateUtils.dateOnly(DateTime.now())
      : DateUtils.dateOnly(widget.items.first.scheduledAt);
  @override
  Widget build(BuildContext context) {
    final agenda =
        widget.items
            .where(
              (item) => DateUtils.isSameDay(item.scheduledAt, selectedDate),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (widget.items.isEmpty) {
      return const Text('No active scheduled sessions.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final calendar = CalendarDatePicker(
          initialDate: selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 730)),
          onDateChanged: (value) => setState(() => selectedDate = value),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sessions on ${_date(selectedDate)}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 10),
            if (agenda.isEmpty)
              const Text('No sessions scheduled for this day.'),
            ...agenda.map(
              (item) =>
                  _AppointmentCard(item: item, repository: widget.repository),
            ),
          ],
        );
        if (constraints.maxWidth < 850) {
          return Column(children: [calendar, details]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 380, child: calendar),
            const SizedBox(width: 20),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _AssessmentsPage extends StatefulWidget {
  const _AssessmentsPage({required this.repository});
  final AdminPortalRepository repository;
  @override
  State<_AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends State<_AssessmentsPage> {
  String filter = 'All Types';
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Assessments',
    subtitle: 'Track and manage assessment results',
    child: StreamBuilder<List<AdminAssessmentRecord>>(
      stream: widget.repository.watchAssessments(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _AccessPanel();
        final all = snapshot.data ?? const <AdminAssessmentRecord>[];
        final items = filter == 'All Types'
            ? all
            : all
                  .where((a) => a.type.toLowerCase() == filter.toLowerCase())
                  .toList();
        final types = [
          'All Types',
          ...{for (final item in all) item.type},
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Filter(
              label: 'Filter:',
              value: filter,
              values: types,
              onChanged: (v) => setState(() => filter = v!),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              values: {
                'Total Assessments': all.length,
                'Completed': all
                    .where((a) => (a.status ?? '').isNotEmpty)
                    .length,
                'Pending': all.where((a) => (a.status ?? '').isEmpty).length,
              },
            ),
            const SizedBox(height: 18),
            Container(
              decoration: _box,
              child: _ResponsiveTable(
                columns: const [
                  'User ID',
                  'Type',
                  'Assessment Type',
                  'Date',
                  'Score',
                  'Status',
                  'Actions',
                ],
                rows: items
                    .map(
                      (a) => [
                        a.userId,
                        a.role ?? 'User',
                        a.type,
                        _date(a.createdAt),
                        a.score?.toString() ?? '-',
                        _Tag(
                          label: a.status ?? 'Pending',
                          color: (a.status ?? '').isEmpty
                              ? _softAmber
                              : _success,
                        ),
                        const Icon(Icons.visibility_outlined, color: _yellow),
                      ],
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _InquiriesPage extends StatefulWidget {
  const _InquiriesPage({required this.repository});
  final AdminPortalRepository repository;
  @override
  State<_InquiriesPage> createState() => _InquiriesPageState();
}

class _InquiriesPageState extends State<_InquiriesPage> {
  String status = 'All Status';
  String category = 'All Categories';
  AdminInquiryModel? selected;
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Inquiry Management',
    subtitle: 'Manage student and faculty inquiries',
    child: StreamBuilder<List<AdminInquiryModel>>(
      stream: widget.repository.watchInquiries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _AccessPanel();
        final all = snapshot.data ?? const <AdminInquiryModel>[];
        final categories = [
          'All Categories',
          ...{for (final item in all) item.category},
        ];
        final items = all
            .where(
              (i) =>
                  (status == 'All Status' || i.status.label == status) &&
                  (category == 'All Categories' || i.category == category),
            )
            .toList();
        final current = selected == null
            ? (items.isEmpty ? null : items.first)
            : items.contains(selected)
            ? selected
            : items.isEmpty
            ? null
            : items.first;
        return Column(
          children: [
            _FilterRow(
              children: [
                _Filter(
                  label: 'Filter:',
                  value: status,
                  values: const [
                    'All Status',
                    'Pending',
                    'In Progress',
                    'Resolved',
                  ],
                  onChanged: (v) => setState(() => status = v!),
                ),
                _Filter(
                  label: '',
                  value: category,
                  values: categories,
                  onChanged: (v) => setState(() => category = v!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, box) => box.maxWidth < 900
                  ? Column(
                      children: [
                        _InquiryList(
                          items: items,
                          selected: current,
                          onSelect: (i) => setState(() => selected = i),
                        ),
                        const SizedBox(height: 16),
                        _InquiryDetails(
                          item: current,
                          repository: widget.repository,
                          onUpdated: () => setState(() {}),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _InquiryList(
                            items: items,
                            selected: current,
                            onSelect: (i) => setState(() => selected = i),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _InquiryDetails(
                            item: current,
                            repository: widget.repository,
                            onUpdated: () => setState(() {}),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _InquiryList extends StatelessWidget {
  const _InquiryList({
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  final List<AdminInquiryModel> items;
  final AdminInquiryModel? selected;
  final ValueChanged<AdminInquiryModel> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    children: items.isEmpty
        ? [
            const _EmptyPanel(
              message: 'No inquiries match the selected filters.',
            ),
          ]
        : items
              .map(
                (item) => InkWell(
                  onTap: () => onSelect(item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(24),
                    decoration: _box.copyWith(
                      color: item.id == selected?.id
                          ? AdminColors.surface
                          : Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subject,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${item.displayName} • ${item.email}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 15),
                        Wrap(
                          spacing: 12,
                          children: [
                            _Tag(
                              label: item.status.label,
                              color: _statusColor(item.status.storedValue),
                            ),
                            Text(item.category),
                            Text(_date(item.createdAt)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
  );
}

class _InquiryDetails extends StatelessWidget {
  const _InquiryDetails({
    required this.item,
    required this.repository,
    required this.onUpdated,
  });
  final AdminInquiryModel? item;
  final AdminPortalRepository repository;
  final VoidCallback onUpdated;
  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const _EmptyPanel(
        message: 'Select an inquiry to view its details.',
      );
    }
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: _box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inquiry Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _Detail(label: 'Subject', value: item!.subject),
          _Detail(label: 'Name', value: item!.displayName),
          _Detail(label: 'Email', value: item!.email),
          _Detail(label: 'Type', value: item!.role ?? 'User'),
          _Detail(label: 'Category', value: item!.category),
          _Detail(label: 'Message', value: item!.message),
          const SizedBox(height: 26),
          const Center(
            child: Text(
              'Update Status',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          for (final next in InquiryStatus.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _statusColor(next.storedValue),
                    foregroundColor: next == InquiryStatus.pending
                        ? Colors.black
                        : Colors.white,
                  ),
                  onPressed: () async {
                    await repository.updateInquiryStatus(item!.id, next);
                    onUpdated();
                  },
                  child: Text('Mark as ${next.label}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.repository});
  final AdminPortalRepository repository;
  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _Page(
        title: 'Profile Settings',
        subtitle: 'Manage your account information and preferences',
        child: _AccessPanel(),
      );
    }
    name.text = name.text.isEmpty ? user.displayName ?? '' : name.text;
    email.text = email.text.isEmpty ? user.email ?? '' : email.text;
    return _Page(
      title: 'Profile Settings',
      subtitle: 'Manage your account information and preferences',
      child: LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 46,
          runSpacing: 18,
          children: [
            Container(
              width: 380,
              height: 650,
              padding: const EdgeInsets.all(32),
              decoration: _box,
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 75,
                    backgroundColor: _yellow,
                    child: Icon(
                      Icons.account_circle,
                      color: Colors.white,
                      size: 115,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    name.text.isEmpty ? 'Admin User' : name.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _yellow),
                    onPressed: () {},
                    child: const Text('Change Photo'),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: box.maxWidth > 900 ? box.maxWidth - 430 : 600,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(34),
                    decoration: _box,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 35),
                        Wrap(
                          spacing: 30,
                          runSpacing: 22,
                          children: [
                            SizedBox(
                              width: 380,
                              child: TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 380,
                              child: TextField(
                                controller: email,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 380,
                              child: TextField(
                                controller: phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone number',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _yellow,
                            ),
                            onPressed: () =>
                                widget.repository.updateOwnProfile(user.uid, {
                                  'name': name.text.trim(),
                                  'email': email.text.trim(),
                                  'phone': phone.text.trim(),
                                  'updatedAt': DateTime.now(),
                                }),
                            child: const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(34),
                    decoration: _box,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 22),
                        TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Available after admin authentication',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.values});
  final Map<String, int> values;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    runSpacing: 14,
    children: values.entries
        .map(
          (e) => _StatCard(
            label: e.key,
            value: '${e.value}',
            note: '',
            icon: Icons.assignment_outlined,
            color: _softAmber,
          ),
        )
        .toList(),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label, value;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: _box,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
        ],
        DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          items: values
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 12, runSpacing: 10, children: children);
}

class _ResponsiveTable extends StatelessWidget {
  const _ResponsiveTable({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<Object>> rows;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: columns
          .map(
            (c) => DataColumn(
              label: Text(
                c,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          )
          .toList(),
      rows: rows
          .map(
            (row) => DataRow(
              cells: row
                  .map(
                    (cell) => DataCell(cell is Widget ? cell : Text('$cell')),
                  )
                  .toList(),
            ),
          )
          .toList(),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

class _AccessPanel extends StatelessWidget {
  const _AccessPanel();
  @override
  Widget build(BuildContext context) => const _EmptyPanel(
    message:
        'Live admin data requires an authenticated Firebase user with an admin or counselor role.',
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: _box,
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.black54),
    ),
  );
}

String _date(DateTime? date) => date == null
    ? '-'
    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _appointmentError(Object error) {
  final message = FirebaseErrorMessage.describe(
    error,
    fallback:
        'The appointment change was not confirmed. Check your connection and retry.',
  );
  final correlationId = FirebaseRuntimeDiagnostics.correlationIdFrom(error);
  return correlationId == null ? message : '$message Reference: $correlationId';
}

String _dateTime(DateTime date) =>
    '${_date(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
Color _statusColor(String status) =>
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      'resolved' || 'complete' => _success,
      'in_progress' || 'confirmed' => _purple,
      _ => _softAmber,
    };
final _box = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  boxShadow: const [
    BoxShadow(color: Color(0x38000000), blurRadius: 3, offset: Offset(0, 3)),
  ],
);

class _LinePainter extends CustomPainter {
  const _LinePainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        grid,
      );
    }
    final p = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        size.width * i / (values.length - 1),
        size.height - values[i] * (size.height - 18) - 9,
      );
      i == 0 ? p.moveTo(point.dx, point.dy) : p.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = _yellow
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values;
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.ratio);
  final double ratio;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect,
      -1.5708,
      6.283 * ratio,
      true,
      Paint()..color = _yellow,
    );
    canvas.drawArc(
      rect,
      -1.5708 + 6.283 * ratio,
      6.283 * (1 - ratio),
      true,
      Paint()..color = AdminColors.highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.ratio != ratio;
}
