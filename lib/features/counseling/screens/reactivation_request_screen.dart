import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../providers/user_provider.dart';

/// The local payload that will be delivered to the Admin Web in a later phase.
class ReactivationRequestDraft {
  const ReactivationRequestDraft({
    required this.studentName,
    required this.studentNumber,
    required this.course,
    required this.college,
    required this.yearLevel,
    required this.email,
    required this.contactNumber,
    required this.address,
    required this.requestDate,
    required this.semester,
    required this.academicYear,
    required this.reason,
    required this.leaveStatus,
    required this.leaveDetail,
    required this.attachments,
    required this.createdAt,
  });

  final String studentName, studentNumber, course, college, yearLevel, email;
  final String contactNumber, address, semester, academicYear, reason;
  final String leaveStatus, leaveDetail;
  final DateTime requestDate, createdAt;
  final Map<String, XFile?> attachments;
  String get status => 'pending_review';
}

/// Intentionally has no network side effects until Admin Web delivery is built.
class LocalReactivationRequestSubmission {
  const LocalReactivationRequestSubmission();
  Future<ReactivationRequestDraft> submit(
    ReactivationRequestDraft draft,
  ) async => draft;
}

class ReactivationRequestScreen extends StatefulWidget {
  const ReactivationRequestScreen({
    super.key,
    this.submission = const LocalReactivationRequestSubmission(),
  });
  final LocalReactivationRequestSubmission submission;

  @override
  State<ReactivationRequestScreen> createState() =>
      _ReactivationRequestScreenState();
}

class _ReactivationRequestScreenState extends State<ReactivationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _studentNo = TextEditingController();
  final _course = TextEditingController();
  final _college = TextEditingController();
  final _yearLevel = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _academicYear = TextEditingController();
  final _reason = TextEditingController();
  final _leaveDetail = TextEditingController();
  final Map<String, XFile?> _attachments = {
    'Student supporting document': null,
    'Guidance director approval': null,
    'Dean approval': null,
    'Registrar approval': null,
  };
  DateTime _requestDate = DateUtils.dateOnly(DateTime.now());
  String? _semester;
  String? _leaveStatus;
  bool _prefilled = false;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    UserModel? user;
    try {
      user = context.read<UserProvider>().user;
    } on ProviderNotFoundException {
      user = null;
    }
    if (user != null) {
      _name.text = user.displayName;
      _studentNo.text = user.schoolId ?? '';
      _course.text = user.course ?? '';
      _college.text = user.department ?? user.collegeId ?? '';
      _yearLevel.text = user.yearLevel ?? '';
      _email.text = user.email;
    }
    _prefilled = true;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _studentNo,
      _course,
      _college,
      _yearLevel,
      _email,
      _contact,
      _address,
      _academicYear,
      _reason,
      _leaveDetail,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAF5E8),
    appBar: AppBar(
      title: const Text('Registrar Copy'),
      backgroundColor: const Color(0xFFFFCD3A),
      foregroundColor: Colors.black,
    ),
    body: SafeArea(
      top: false,
      child: _submitted ? _SuccessView(onDone: _done) : _form(),
    ),
  );

  Widget _form() => Form(
    key: _formKey,
    child: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const _Banner(),
        const SizedBox(height: 18),
        _Section(
          title: 'Student information',
          children: [
            _field(_name, 'Full name'),
            _field(_studentNo, 'Student number'),
            _field(_course, 'Course'),
            _field(_college, 'College'),
            _field(_yearLevel, 'Year level'),
            _field(
              _email,
              'Email address',
              required: false,
              type: TextInputType.emailAddress,
            ),
            _field(_contact, 'Contact number', type: TextInputType.phone),
            _field(_address, 'Address', lines: 2),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Request details',
          children: [
            _DateField(value: _requestDate, onTap: _pickDate),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _semester,
              decoration: _input('Semester'),
              items: const ['First Semester', 'Second Semester', 'Summer']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _semester = value),
              validator: (value) => value == null ? 'Select a semester.' : null,
            ),
            const SizedBox(height: 12),
            _field(_academicYear, 'Academic year (e.g. 2026–2027)'),
            _field(_reason, 'Reason for reactivation', lines: 4),
            const Text(
              'Leave of absence status',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            RadioGroup<String>(
              groupValue: _leaveStatus,
              onChanged: (value) => setState(() {
                _leaveStatus = value;
                _leaveDetail.clear();
              }),
              child: const Column(
                children: [
                  RadioListTile(
                    value: 'Filed leave of absence',
                    title: Text('I filed a leave of absence'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile(
                    value: 'Did not file leave of absence',
                    title: Text('I did not file a leave of absence'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            if (_leaveStatus == null)
              const _ErrorText('Choose a leave-of-absence status.'),
            if (_leaveStatus != null)
              _field(
                _leaveDetail,
                _leaveStatus == 'Filed leave of absence'
                    ? 'Leave filed date or details'
                    : 'Why a leave was not filed',
                lines: 2,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Attachments (optional)',
          subtitle:
              'Photos are kept only for this session until Admin Web delivery is added.',
          children: [
            for (final item in _attachments.entries)
              _AttachmentTile(
                label: item.key,
                file: item.value,
                onPick: () => _pickAttachment(item.key),
                onRemove: () => setState(() => _attachments[item.key] = null),
              ),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC62E),
              foregroundColor: Colors.black,
              shape: const StadiumBorder(),
            ),
            child: Text(
              _submitting ? 'Preparing request…' : 'Submit request',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    int lines = 1,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType: type,
      decoration: _input(label),
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? 'Required.' : null
          : null,
    ),
  );

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3DABF)),
    ),
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _requestDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) setState(() => _requestDate = value);
  }

  Future<void> _pickAttachment(String key) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(source: source, imageQuality: 82);
    if (file != null && mounted) setState(() => _attachments[key] = file);
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid ||
        _semester == null ||
        _leaveStatus == null ||
        _leaveDetail.text.trim().isEmpty) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }
    setState(() => _submitting = true);
    await widget.submission.submit(
      ReactivationRequestDraft(
        studentName: _name.text.trim(),
        studentNumber: _studentNo.text.trim(),
        course: _course.text.trim(),
        college: _college.text.trim(),
        yearLevel: _yearLevel.text.trim(),
        email: _email.text.trim(),
        contactNumber: _contact.text.trim(),
        address: _address.text.trim(),
        requestDate: _requestDate,
        semester: _semester!,
        academicYear: _academicYear.text.trim(),
        reason: _reason.text.trim(),
        leaveStatus: _leaveStatus!,
        leaveDetail: _leaveDetail.text.trim(),
        attachments: Map.unmodifiable(_attachments),
        createdAt: DateTime.now(),
      ),
    );
    if (mounted)
      setState(() {
        _submitting = false;
        _submitted = true;
      });
  }

  void _done() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.pop();
  }
}

class _Banner extends StatelessWidget {
  const _Banner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFC62E),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: const Column(
      children: [
        Text(
          'APPLICATION FOR REACTIVATION\nOF ENROLLMENT',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 8),
        Text(
          'University Registrar • Urdaneta City University',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E5),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!, style: const TextStyle(fontSize: 12, height: 1.3)),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});
  final DateTime value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: 'Request date',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 19),
          const SizedBox(width: 10),
          Text(MaterialLocalizations.of(context).formatMediumDate(value)),
        ],
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: Colors.red, fontSize: 12)),
  );
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.label,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });
  final String label;
  final XFile? file;
  final VoidCallback onPick, onRemove;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3DABF)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: file == null
                ? const Icon(Icons.upload_file_outlined)
                : FutureBuilder<Uint8List>(
                    future: file!.readAsBytes(),
                    builder: (_, snapshot) => snapshot.hasData
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file?.name ?? label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (file != null)
            IconButton(
              tooltip: 'Remove $label',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          TextButton(
            onPressed: onPick,
            child: Text(file == null ? 'Upload' : 'Replace'),
          ),
        ],
      ),
    ),
  );
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 38, 24, 28),
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                color: Color(0xFFFFC62E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check, size: 70),
            ),
            const SizedBox(height: 24),
            const Text(
              'Wait for PACC\nAnnouncement',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            const Text(
              'You’ll receive a confirmation email shortly.\nWe look forward to seeing you!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            const Text('🎉', style: TextStyle(fontSize: 38)),
            const SizedBox(height: 28),
            SizedBox(
              width: 180,
              height: 50,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC62E),
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
