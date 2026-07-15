import 'package:flutter/material.dart';

import '../../../repositories/admin_portal_repository.dart';
import '../domain/admin_management_models.dart';

class StaffRegistrationScreen extends StatefulWidget {
  const StaffRegistrationScreen({super.key, required this.repository});
  final AdminPortalRepository repository;
  @override
  State<StaffRegistrationScreen> createState() =>
      _StaffRegistrationScreenState();
}

class _StaffRegistrationScreenState extends State<StaffRegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final fields = List.generate(7, (_) => TextEditingController());
  String? departmentId;
  String? collegeId;
  String? courseId;
  bool busy = false;
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Register Staff Account')),
    body: StreamBuilder<List<Department>>(
      stream: widget.repository.watchDepartments(),
      builder: (context, departments) => StreamBuilder<List<College>>(
        stream: widget.repository.watchColleges(),
        builder: (context, colleges) => StreamBuilder<List<Course>>(
          stream: widget.repository.watchCourses(),
          builder: (context, courses) {
            final departmentItems = (departments.data ?? [])
                .where((e) => e.active)
                .toList();
            final collegeItems = (colleges.data ?? [])
                .where((e) => e.active)
                .toList();
            final courseItems = (courses.data ?? [])
                .where((e) => e.active && e.collegeId == collegeId)
                .toList();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            const Text(
                              'Staff access requires administrator approval.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 18),
                            _field(0, 'First name'),
                            _field(1, 'Last name'),
                            _field(2, 'Employee ID'),
                            _field(3, 'Email', email: true),
                            _field(4, 'Password', password: true),
                            _field(5, 'Position'),
                            DropdownButtonFormField<String>(
                              initialValue: departmentId,
                              decoration: const InputDecoration(
                                labelText: 'Department',
                              ),
                              items: departmentItems
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text('${e.code} — ${e.name}'),
                                    ),
                                  )
                                  .toList(),
                              validator: (v) => v == null ? 'Required' : null,
                              onChanged: (v) =>
                                  setState(() => departmentId = v),
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: collegeId,
                              decoration: const InputDecoration(
                                labelText: 'College (optional)',
                              ),
                              items: collegeItems
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text('${e.code} — ${e.name}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() {
                                collegeId = v;
                                courseId = null;
                              }),
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: courseId,
                              decoration: const InputDecoration(
                                labelText: 'Course (optional)',
                              ),
                              items: courseItems
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text('${e.code} — ${e.name}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => courseId = v),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: busy ? null : _submit,
                                child: Text(
                                  busy ? 'Submitting…' : 'Submit registration',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _field(
    int index,
    String label, {
    bool email = false,
    bool password = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: fields[index],
      obscureText: password,
      keyboardType: email ? TextInputType.emailAddress : null,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Required';
        if (password && v.length < 6) return 'Use at least 6 characters';
        if (email && !v.contains('@')) return 'Enter a valid email';
        return null;
      },
    ),
  );

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.repository.registerStaff(
        email: fields[3].text,
        password: fields[4].text,
        firstName: fields[0].text,
        lastName: fields[1].text,
        employeeId: fields[2].text,
        position: fields[5].text,
        departmentId: departmentId!,
        collegeId: collegeId ?? '',
        courseId: courseId ?? '',
      );
      await widget.repository.signOut();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Registration submitted'),
          content: Text('Your account is pending administrator approval.'),
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
