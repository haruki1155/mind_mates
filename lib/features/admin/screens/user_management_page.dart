import 'package:flutter/material.dart';

import '../../../models/profile_roles.dart';
import '../../../models/user_model.dart';
import '../../../repositories/admin_portal_repository.dart';
import '../domain/admin_management_models.dart';

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
  late Future<List<PublicAppUserRecord>> publicUsers;
  int? publicUserCount;

  @override
  void initState() {
    super.initState();
    publicUsers = _loadPublicUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.isSuperAdmin) {
      return const Center(
        child: Text('Super-administrator access is required.'),
      );
    }
    return Material(
      color: Colors.transparent,
      child: StreamBuilder<List<UserModel>>(
        stream: widget.repository.watchUsers(),
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
                const Text(
                  'User Management',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const Text(
                  'Privacy-safe app users and staff access management',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _categoryButton(
                            UserManagementCategory.appUsers,
                            'App Users (${publicUserCount ?? '…'})',
                          ),
                          _categoryButton(
                            UserManagementCategory.staff,
                            'Staff / Counselors (${staff.length})',
                          ),
                          _categoryButton(
                            UserManagementCategory.admin,
                            'Admin (${admins.length})',
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showOrganizationDirectory,
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text('Organization Directory'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: category == UserManagementCategory.appUsers
                        ? 'Search public user ID'
                        : 'Search staff',
                    border: const OutlineInputBorder(),
                  ),
                ),
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

  Widget _appUsersTable() => FutureBuilder<List<PublicAppUserRecord>>(
    future: publicUsers,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text('Unable to load anonymous app users.'),
            FilledButton(
              onPressed: _refreshPublicUsers,
              child: const Text('Retry'),
            ),
          ],
        );
      }
      final users = (snapshot.data ?? const <PublicAppUserRecord>[])
          .where((user) => user.publicUserId.toLowerCase().contains(query))
          .toList();
      if (users.isEmpty) return const Text('No app users found.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Private profile information is intentionally hidden.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Public User ID')),
                DataColumn(label: Text('Category')),
              ],
              rows: users
                  .map(
                    (user) => DataRow(
                      cells: [
                        DataCell(Text(user.publicUserId)),
                        DataCell(Text(user.populationRole.label)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    },
  );

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
    setState(() => publicUsers = _loadPublicUsers());
  }

  Future<List<PublicAppUserRecord>> _loadPublicUsers() async {
    final users = await widget.repository.listPublicAppUsers();
    if (mounted) setState(() => publicUserCount = users.length);
    return users;
  }

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
