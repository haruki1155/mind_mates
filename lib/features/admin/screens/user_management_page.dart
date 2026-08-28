import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/profile_roles.dart';
import '../../../models/user_model.dart';
import '../../../repositories/admin_portal_repository.dart';
import '../domain/admin_management_models.dart';
import '../domain/admin_colors.dart';

enum UserManagementCategory { appUsers, staff, admin }

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key, required this.repository});
  final AdminPortalRepository repository;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  UserManagementCategory category = UserManagementCategory.appUsers;
  String query = '';
  String roleFilter = 'all';
  String departmentFilter = '';
  String courseFilter = '';
  String yearLevelFilter = '';
  Timer? _filterDebounce;
  List<PublicAppUserRecord> publicUsers = const [];
  String? nextPublicCursor;
  bool loadingPublicUsers = true;
  String? publicUsersError;
  int? publicUserCount;
  bool deletingInactiveUsers = false;
  int _publicLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadPublicUsers(reset: true);
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    super.dispose();
  }

  void _scheduleFilteredReload() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadPublicUsers(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.repository.isSuperAdmin;
    return Material(
      color: Colors.transparent,
      child: StreamBuilder<List<UserModel>>(
        // Approved portal staff only need the callable-backed anonymous
        // directory. Never open the private profile collection for them.
        stream: isSuperAdmin
            ? widget.repository.watchUsers()
            : Stream.value(const <UserModel>[]),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load user management.'));
          }
          final all = snapshot.data ?? const <UserModel>[];
          final staff = all
              .where(
                (user) =>
                    user.staffAccountStatus != null &&
                    user.accessRole != AccessRole.admin,
              )
              .toList();
          final admins = all
              .where((user) => user.accessRole == AccessRole.admin)
              .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Privacy-safe app users and staff access management',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AdminColors.textMuted),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _categoryButton(
                          UserManagementCategory.appUsers,
                          'App Users (${publicUserCount ?? '…'})',
                        ),
                        if (isSuperAdmin)
                          _categoryButton(
                            UserManagementCategory.staff,
                            'Staff / Counselors (${staff.length})',
                          ),
                        if (isSuperAdmin)
                          _categoryButton(
                            UserManagementCategory.admin,
                            'Admin (${admins.length})',
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (isSuperAdmin &&
                            kDebugMode &&
                            category == UserManagementCategory.appUsers)
                          FilledButton.icon(
                            onPressed: deletingInactiveUsers
                                ? null
                                : _deleteInactiveUsers,
                            icon: deletingInactiveUsers
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_forever_outlined),
                            label: const Text('Delete inactive test users'),
                          ),
                        if (isSuperAdmin)
                          OutlinedButton.icon(
                            onPressed: _showOrganizationDirectory,
                            icon: const Icon(Icons.account_tree_outlined),
                            label: const Text('Organization Directory'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) {
                    setState(() => query = value.trim().toLowerCase());
                    if (category == UserManagementCategory.appUsers) {
                      _scheduleFilteredReload();
                    }
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: category == UserManagementCategory.appUsers
                        ? 'Search public ID, role, department, course, or year'
                        : 'Search staff',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (category == UserManagementCategory.appUsers) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: roleFilter,
                    decoration: const InputDecoration(
                      labelText: 'Institutional role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All roles')),
                      DropdownMenuItem(
                        value: 'Student',
                        child: Text('Student'),
                      ),
                      DropdownMenuItem(
                        value: 'Teaching',
                        child: Text('Teaching'),
                      ),
                      DropdownMenuItem(
                        value: 'Non-Teaching',
                        child: Text('Non-Teaching'),
                      ),
                      DropdownMenuItem(
                        value: 'Unknown',
                        child: Text('Unknown'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => roleFilter = value ?? 'all');
                      _loadPublicUsers(reset: true);
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _academicFilterField(
                        label: 'Department filter',
                        onChanged: (value) {
                          departmentFilter = value.trim().toLowerCase();
                          _scheduleFilteredReload();
                        },
                      ),
                      _academicFilterField(
                        label: 'Course filter',
                        onChanged: (value) {
                          courseFilter = value.trim().toLowerCase();
                          _scheduleFilteredReload();
                        },
                      ),
                      _academicFilterField(
                        label: 'Year level filter',
                        onChanged: (value) {
                          yearLevelFilter = value.trim().toLowerCase();
                          _scheduleFilteredReload();
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: switch (category) {
                      UserManagementCategory.appUsers => _appUsersTable(),
                      UserManagementCategory.staff => _staffTable(staff),
                      UserManagementCategory.admin => _adminProfiles(admins),
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _categoryButton(UserManagementCategory value, String label) =>
      ChoiceChip(
        selected: category == value,
        label: Text(label),
        onSelected: (_) => setState(() {
          category = value;
          query = '';
        }),
      );

  Widget _academicFilterField({
    required String label,
    required ValueChanged<String> onChanged,
  }) => SizedBox(
    width: 210,
    child: TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _appUsersTable() {
    if (loadingPublicUsers && publicUsers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (publicUsersError != null && publicUsers.isEmpty) {
      return Column(
        children: [
          Text(publicUsersError!),
          FilledButton(
            onPressed: _refreshPublicUsers,
            child: const Text('Retry'),
          ),
        ],
      );
    }
    final users = publicUsers
        .where(
          (user) => [
            user.publicUserId,
            user.populationRoleLabel,
            user.department,
            user.course,
            user.yearLevel,
          ].any((value) => value.toLowerCase().contains(query)),
        )
        .where(
          (user) =>
              roleFilter == 'all' || user.populationRoleLabel == roleFilter,
        )
        .toList();
    if (users.isEmpty) {
      return const Text('No app users match the current filters.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Anonymous academic directory. Personal profile information is intentionally hidden.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                children: users
                    .map(
                      (user) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.publicUserId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Chip(label: Text(user.populationRoleLabel)),
                              Text(
                                user.department.isEmpty
                                    ? 'No department'
                                    : user.department,
                              ),
                              Text(
                                user.course.isEmpty ? 'No course' : user.course,
                              ),
                              Text(
                                user.yearLevel.isEmpty
                                    ? 'No year level'
                                    : user.yearLevel,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Public User ID')),
                  DataColumn(label: Text('Institutional role')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Course')),
                  DataColumn(label: Text('Year level')),
                ],
                rows: users
                    .map(
                      (user) => DataRow(
                        cells: [
                          DataCell(Text(user.publicUserId)),
                          DataCell(Chip(label: Text(user.populationRoleLabel))),
                          DataCell(
                            Text(
                              user.department.isEmpty ? '—' : user.department,
                            ),
                          ),
                          DataCell(
                            Text(user.course.isEmpty ? '—' : user.course),
                          ),
                          DataCell(
                            Text(user.yearLevel.isEmpty ? '—' : user.yearLevel),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
        if (publicUsersError != null) ...[
          const SizedBox(height: 8),
          Text(
            publicUsersError!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        if (nextPublicCursor != null || loadingPublicUsers) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: loadingPublicUsers ? null : () => _loadPublicUsers(),
            icon: loadingPublicUsers
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: const Text('Load more'),
          ),
        ],
      ],
    );
  }

  Widget _staffTable(List<UserModel> values) {
    final staff = values
        .where(
          (user) =>
              query.isEmpty ||
              user.displayName.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              (user.employeeId ?? '').toLowerCase().contains(query),
        )
        .toList();
    if (staff.isEmpty) return const Text('No staff accounts found.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Contact')),
          DataColumn(label: Text('Employee ID')),
          DataColumn(label: Text('Position / Department')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Portal Role')),
          DataColumn(label: Text('Actions')),
        ],
        rows: staff
            .map(
              (user) => DataRow(
                cells: [
                  DataCell(Text(user.displayName)),
                  DataCell(Text(user.email)),
                  DataCell(Text(user.employeeId ?? '—')),
                  DataCell(
                    Text(
                      [user.position, user.department ?? user.departmentId]
                          .whereType<String>()
                          .where((v) => v.isNotEmpty)
                          .join(' / '),
                    ),
                  ),
                  DataCell(Text(user.staffAccountStatus?.label ?? '—')),
                  DataCell(Text(user.accessRole.storedValue)),
                  DataCell(Wrap(spacing: 6, children: _staffActions(user))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  List<Widget> _staffActions(UserModel user) {
    final status = user.staffAccountStatus;
    if (status == StaffAccountStatus.pending) {
      return [
        FilledButton.icon(
          onPressed: () => _verify(user),
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Verify'),
        ),
        OutlinedButton.icon(
          onPressed: () => _review(user),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Review'),
        ),
        TextButton.icon(
          onPressed: () => _reject(user),
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
        ),
      ];
    }
    return [
      OutlinedButton(
        onPressed: () => _review(user),
        child: const Text('Review'),
      ),
      if (status == StaffAccountStatus.approved)
        OutlinedButton(
          onPressed: () => _changeRole(user),
          child: const Text('Change Role'),
        ),
      if (status == StaffAccountStatus.approved)
        TextButton(
          onPressed: () => _setEnabled(user, false),
          child: const Text('Disable'),
        ),
      if (status == StaffAccountStatus.disabled ||
          status == StaffAccountStatus.rejected)
        FilledButton(
          onPressed: () => _setEnabled(user, true),
          child: Text(
            status == StaffAccountStatus.rejected ? 'Reconsider' : 'Enable',
          ),
        ),
      IconButton(
        tooltip: 'Audit history',
        onPressed: () => _audit(user),
        icon: const Icon(Icons.history),
      ),
    ];
  }

  Widget _adminProfiles(List<UserModel> admins) {
    if (admins.isEmpty) {
      return const Text('The configured administrator profile was not found.');
    }
    return Column(
      children: admins
          .map(
            (user) => ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings),
              ),
              title: Text(user.displayName),
              subtitle: Text(
                '${user.email}\nEmployee ID: ${user.employeeId ?? '—'}\nPosition: ${user.position ?? '—'}\nDepartment: ${user.department ?? user.departmentId ?? '—'}',
              ),
              trailing: const Chip(label: Text('Immutable Admin')),
            ),
          )
          .toList(),
    );
  }

  Future<void> _verify(UserModel user) async {
    var role = AccessRole.portalStaff;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('Verify ${user.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                onChanged: (value) {
                  if (value != null) setDialogState(() => role = value);
                },
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Approval reason'),
              ),
            ],
          ),
          actions: _confirmActions(dialogContext, 'Verify'),
        ),
      ),
    );
    if (confirmed == true && reason.text.trim().length >= 3) {
      await widget.repository.reviewStaffRegistration(
        userId: user.id,
        approve: true,
        accessRole: role,
        reason: reason.text,
      );
    }
    reason.dispose();
  }

  Future<void> _reject(UserModel user) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reject ${user.displayName}'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Rejection reason'),
        ),
        actions: _confirmActions(dialogContext, 'Reject'),
      ),
    );
    if (confirmed == true && reason.text.trim().length >= 3) {
      await widget.repository.reviewStaffRegistration(
        userId: user.id,
        approve: false,
        accessRole: AccessRole.portalStaff,
        reason: reason.text,
      );
    }
    reason.dispose();
  }

  Future<void> _review(UserModel user) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Staff registration — ${user.displayName}'),
      content: SizedBox(
        width: 620,
        child: ListView(
          shrinkWrap: true,
          children: [
            _detail('Email', user.email),
            _detail('Employee ID', user.employeeId),
            _detail('Position', user.position),
            _detail('Department', user.department ?? user.departmentId),
            _detail('College', user.collegeId),
            _detail('Course', user.courseId),
            _detail('Account status', user.staffAccountStatus?.label),
            _detail('Portal role', user.accessRole.storedValue),
            _detail('Registered', _date(user.createdAt)),
            _detail('Verified', _date(user.verifiedAt)),
            const Divider(),
            const Text(
              'Audit history',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            StreamBuilder<List<AdminAuditEvent>>(
              stream: widget.repository.watchAdminAudit(user.id),
              builder: (_, snapshot) => Column(
                children: (snapshot.data ?? const [])
                    .map(
                      (event) => ListTile(
                        dense: true,
                        title: Text(event.action),
                        subtitle: Text(event.reason),
                        trailing: Text(_date(event.createdAt)),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
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

  Widget _detail(String label, String? value) => ListTile(
    dense: true,
    title: Text(label),
    trailing: Text((value ?? '').isEmpty ? '—' : value!),
  );

  Future<void> _changeRole(UserModel user) async {
    var role = user.accessRole == AccessRole.counselor
        ? AccessRole.counselor
        : AccessRole.portalStaff;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('Change role — ${user.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  if (v != null) setDialogState(() => role = v);
                },
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
          actions: _confirmActions(dialogContext, 'Save'),
        ),
      ),
    );
    if (confirmed == true && reason.text.trim().length >= 3) {
      await widget.repository.assignAccessRole(
        userId: user.id,
        accessRole: role,
        reason: reason.text,
      );
    }
    reason.dispose();
  }

  Future<void> _setEnabled(UserModel user, bool enabled) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${enabled ? 'Enable' : 'Disable'} ${user.displayName}'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: _confirmActions(dialogContext, enabled ? 'Enable' : 'Disable'),
      ),
    );
    if (confirmed == true && reason.text.trim().length >= 3) {
      await widget.repository.setStaffAccountEnabled(
        userId: user.id,
        enabled: enabled,
        reason: reason.text,
      );
    }
    reason.dispose();
  }

  Future<void> _audit(UserModel user) => _review(user);

  List<Widget> _confirmActions(BuildContext context, String action) => [
    TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: const Text('Cancel'),
    ),
    FilledButton(
      onPressed: () => Navigator.pop(context, true),
      child: Text(action),
    ),
  ];

  Future<void> _refreshPublicUsers() async {
    await _loadPublicUsers(reset: true);
  }

  Future<void> _loadPublicUsers({bool reset = false}) async {
    if (loadingPublicUsers && !reset) return;
    if (reset) _publicLoadGeneration++;
    final generation = _publicLoadGeneration;
    setState(() {
      loadingPublicUsers = true;
      publicUsersError = null;
      if (reset) {
        publicUsers = const [];
        nextPublicCursor = null;
      }
    });
    try {
      final page = await widget.repository.fetchPublicAppUsersPage(
        cursor: reset ? null : nextPublicCursor,
        search: query,
        role: switch (roleFilter) {
          'Student' => 'student',
          'Teaching' => 'teaching',
          'Non-Teaching' => 'nonTeaching',
          'Unknown' => 'unknown',
          _ => '',
        },
        department: departmentFilter,
        course: courseFilter,
        yearLevel: yearLevelFilter,
      );
      if (!mounted || generation != _publicLoadGeneration) return;
      setState(() {
        publicUsers = [...publicUsers, ...page.users];
        nextPublicCursor = page.nextCursor;
        publicUserCount = page.totalAppUsers;
      });
    } catch (_) {
      if (!mounted || generation != _publicLoadGeneration) return;
      setState(() {
        publicUsersError = publicUsers.isEmpty
            ? 'Unable to load anonymous app users. Check your connection and retry.'
            : 'More users could not be loaded. Your current results are still shown.';
      });
    } finally {
      if (mounted && generation == _publicLoadGeneration) {
        setState(() => loadingPublicUsers = false);
      }
    }
  }

  Future<void> _deleteInactiveUsers() async {
    setState(() => deletingInactiveUsers = true);
    try {
      final preview = await widget.repository.previewInactiveAppUserDeletion();
      if (!mounted) return;
      setState(() => deletingInactiveUsers = false);
      if (preview.eligibleCount == 0) {
        await _showCleanupMessage(
          'No inactive app users',
          'No app-user account has been inactive for '
              '${preview.inactiveDays} days. '
              '${preview.skippedMissingActivity} account(s) without an '
              'activity or creation timestamp were safely skipped.',
        );
        return;
      }

      final confirmation = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Permanently delete inactive test users?'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${preview.eligibleCount} app-user account(s) inactive '
                      'since ${_date(preview.cutoff)} or earlier will lose '
                      'Firebase Authentication, Firestore data, Secret Chat '
                      'content, and uploaded images. This cannot be undone.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      preview.publicUserIds.join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (preview.skippedMissingActivity > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${preview.skippedMissingActivity} account(s) with '
                        'missing timestamps will be skipped.',
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmation,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Type DELETE to confirm',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: confirmation.text == 'DELETE'
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        ),
      );
      confirmation.dispose();
      if (confirmed != true || !mounted) return;

      setState(() => deletingInactiveUsers = true);
      final result = await widget.repository.deleteInactiveAppUsers();
      if (!mounted) return;
      await _refreshPublicUsers();
      if (!mounted) return;
      setState(() => deletingInactiveUsers = false);
      await _showCleanupMessage(
        'Inactive-user cleanup finished',
        '${result.deletedCount} account(s) and '
            '${result.deletedDocumentCount} data record(s) were deleted. '
            '${result.failedCount} account(s) failed and can be retried.'
            '${result.failedPublicUserIds.isEmpty ? '' : '\nFailed: ${result.failedPublicUserIds.join(', ')}'}',
      );
    } catch (error) {
      if (mounted) {
        setState(() => deletingInactiveUsers = false);
        await _showCleanupMessage(
          'Inactive-user cleanup failed',
          error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => deletingInactiveUsers = false);
    }
  }

  Future<void> _showCleanupMessage(String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  Future<void> _showOrganizationDirectory() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Organization Directory'),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _organizationList<College>(
                'college',
                'Colleges',
                widget.repository.watchColleges(),
              ),
              _organizationList<Department>(
                'department',
                'Departments',
                widget.repository.watchDepartments(),
              ),
              _organizationList<Course>(
                'course',
                'Courses',
                widget.repository.watchCourses(),
              ),
            ],
          ),
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

  Widget _organizationList<T extends OrganizationRecord>(
    String kind,
    String title,
    Stream<List<T>> stream,
  ) => StreamBuilder<List<T>>(
    stream: stream,
    builder: (_, snapshot) => ExpansionTile(
      title: Text('$title (${snapshot.data?.length ?? 0})'),
      trailing: IconButton(
        tooltip: 'Add $title',
        onPressed: () => _editOrganization(kind),
        icon: const Icon(Icons.add),
      ),
      children: (snapshot.data ?? <T>[])
          .map(
            (record) => ListTile(
              title: Text(record.name),
              subtitle: Text(record.code),
              trailing: Icon(
                record.active ? Icons.check_circle : Icons.pause_circle,
              ),
              onTap: () => _editOrganization(kind, record: record),
            ),
          )
          .toList(),
    ),
  );

  Future<void> _editOrganization(
    String kind, {
    OrganizationRecord? record,
  }) async {
    final name = TextEditingController(text: record?.name);
    final code = TextEditingController(text: record?.code);
    final colleges = kind == 'course'
        ? await widget.repository.watchColleges().first
        : const <College>[];
    String? collegeId = record is Course ? record.collegeId : null;
    var active = record?.active ?? true;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
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
                      .where((college) => college.active)
                      .map(
                        (college) => DropdownMenuItem(
                          value: college.id,
                          child: Text(college.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => collegeId = value),
                ),
              SwitchListTile(
                value: active,
                title: const Text('Active'),
                onChanged: (value) => setDialogState(() => active = value),
              ),
            ],
          ),
          actions: _confirmActions(dialogContext, 'Save'),
        ),
      ),
    );
    if (confirmed == true &&
        name.text.trim().length >= 2 &&
        code.text.trim().isNotEmpty &&
        (kind != 'course' || collegeId != null)) {
      await widget.repository.saveOrganizationRecord(
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

String _date(DateTime? value) => value == null
    ? '—'
    : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
