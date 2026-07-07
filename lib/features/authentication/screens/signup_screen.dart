import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../quick_assessment/models/quick_assessment_models.dart';
import '../../../models/user_model.dart';
import '../../../providers/assessment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../repositories/auth_repository.dart';
import '../auth_flow_routes.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _SignupColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            _BubbleCluster(top: -27, left: -14, mirror: false),
            _BubbleCluster(top: -16, right: -12, mirror: true),
            _SignupBody(),
          ],
        ),
      ),
    );
  }
}

class _SignupBody extends StatefulWidget {
  const _SignupBody();

  @override
  State<_SignupBody> createState() => _SignupBodyState();
}

class _SignupBodyState extends State<_SignupBody> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedDepartment;
  String? _selectedCourse;
  String? _selectedSector;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _schoolIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final requiredError = _requiredValidator(value, 'Confirm password');
    if (requiredError != null) {
      return requiredError;
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    FocusScope.of(context).unfocus();
    final formIsValid = _formKey.currentState?.validate() ?? false;

    if (!formIsValid || !_acceptedTerms) {
      if (!_acceptedTerms) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Please accept Privacy & Term of Use.'),
            ),
          );
      }
      return;
    }

    final assessmentProvider = context.read<AssessmentProvider>();
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final role = assessmentProvider.selectedRole;
    final usesSector = role == AssessmentRole.staff;
    final userId = await authProvider.signUp(
      password: _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      schoolId: _schoolIdController.text,
      department: usesSector ? '' : _selectedDepartment ?? '',
      course: usesSector ? '' : _selectedCourse ?? '',
      sector: usesSector ? _selectedSector : null,
      middleName: _middleNameController.text,
      role: role,
    );

    if (!mounted) return;

    if (userId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              authProvider.errorMessage ?? 'Unable to create account.',
            ),
          ),
        );
      return;
    }

    userProvider.setUser(
      _localProfileFromRegistration(userId: userId, role: role),
    );
    await userProvider.loadProfile(userId);

    if (!mounted) return;
    final destination = destinationAfterAuthentication(
      hasCompletedQuickAssessment: false,
    );
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  UserModel _localProfileFromRegistration({
    required String userId,
    required AssessmentRole? role,
  }) {
    final usesSector = role == AssessmentRole.staff;
    return UserModel(
      id: userId,
      email: AuthRepository.authEmailForSchoolId(_schoolIdController.text),
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      schoolId: _schoolIdController.text.trim(),
      department: usesSector ? null : _selectedDepartment?.trim(),
      course: usesSector ? null : _selectedCourse?.trim(),
      sector: usesSector ? _selectedSector?.trim() : null,
      role: role?.name,
      createdAt: DateTime.now(),
      dayStreak: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(6, screenHeight < 760 ? 22 : 54, 6, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            children: [
              const _LogoHeader(),
              const SizedBox(height: 16),
              const _NoticePanel(),
              const SizedBox(height: 12),
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return _SignupFormCard(
                    formKey: _formKey,
                    role: context.watch<AssessmentProvider>().selectedRole,
                    firstNameController: _firstNameController,
                    middleNameController: _middleNameController,
                    lastNameController: _lastNameController,
                    schoolIdController: _schoolIdController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    selectedDepartment: _selectedDepartment,
                    selectedCourse: _selectedCourse,
                    selectedSector: _selectedSector,
                    acceptedTerms: _acceptedTerms,
                    isLoading: authProvider.isLoading,
                    onDepartmentChanged: (value) {
                      setState(() {
                        _selectedDepartment = value;
                        _selectedCourse = null;
                      });
                    },
                    onCourseChanged: (value) {
                      setState(() => _selectedCourse = value);
                    },
                    onSectorChanged: (value) {
                      setState(() => _selectedSector = value);
                    },
                    onTermsChanged: (value) {
                      setState(() => _acceptedTerms = value ?? false);
                    },
                    onSignUp: _handleSignUp,
                    requiredValidator: _requiredValidator,
                    confirmPasswordValidator: _confirmPasswordValidator,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  static const _logoPath =
      'assets/images/Create Account/Green_and_White_Circle_Minimalist_Garden_Logo-removebg-preview 1.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(_logoPath, width: 150, height: 150, fit: BoxFit.contain);
  }
}

class _NoticePanel extends StatelessWidget {
  const _NoticePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: _SignupColors.notice,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '-- Unofficial --\nRefer to the instructions of UCU-MiS+ FB Page\n+ PACC before using.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _SignupColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.33,
        ),
      ),
    );
  }
}

class _SignupFormCard extends StatelessWidget {
  const _SignupFormCard({
    required this.formKey,
    required this.role,
    required this.firstNameController,
    required this.middleNameController,
    required this.lastNameController,
    required this.schoolIdController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.selectedDepartment,
    required this.selectedCourse,
    required this.selectedSector,
    required this.acceptedTerms,
    required this.isLoading,
    required this.onDepartmentChanged,
    required this.onCourseChanged,
    required this.onSectorChanged,
    required this.onTermsChanged,
    required this.onSignUp,
    required this.requiredValidator,
    required this.confirmPasswordValidator,
  });

  final GlobalKey<FormState> formKey;
  final AssessmentRole? role;
  final TextEditingController firstNameController;
  final TextEditingController middleNameController;
  final TextEditingController lastNameController;
  final TextEditingController schoolIdController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String? selectedDepartment;
  final String? selectedCourse;
  final String? selectedSector;
  final bool acceptedTerms;
  final bool isLoading;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onCourseChanged;
  final ValueChanged<String?> onSectorChanged;
  final ValueChanged<bool?> onTermsChanged;
  final Future<void> Function() onSignUp;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) confirmPasswordValidator;

  @override
  Widget build(BuildContext context) {
    final selectedCourses = _coursesForDepartment(selectedDepartment);
    final usesSector = role == AssessmentRole.staff;

    return Container(
      width: 346,
      padding: const EdgeInsets.fromLTRB(20, 25, 19, 56),
      decoration: BoxDecoration(
        color: _SignupColors.card,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SignupField(
              controller: firstNameController,
              label: 'First Name',
              icon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (value) => requiredValidator(value, 'First name'),
            ),
            const SizedBox(height: 7),
            _SignupField(
              controller: middleNameController,
              label: 'Middle Name',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 7),
            _SignupField(
              controller: lastNameController,
              label: 'Last Name',
              textInputAction: TextInputAction.next,
              validator: (value) => requiredValidator(value, 'Last name'),
            ),
            const SizedBox(height: 7),
            _SignupField(
              controller: schoolIdController,
              label: 'School ID',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              validator: (value) => requiredValidator(value, 'School ID'),
            ),
            const SizedBox(height: 7),
            if (usesSector) ...[
              _SignupDropdownField(
                label: 'Sector',
                icon: Icons.business_center_outlined,
                value: selectedSector,
                items: _sectorOptions,
                onChanged: onSectorChanged,
                validator: (value) => requiredValidator(value, 'Sector'),
              ),
            ] else ...[
              _SignupDropdownField(
                label: 'College or Department',
                icon: Icons.account_balance_outlined,
                value: selectedDepartment,
                items: _collegeCourseOptions
                    .map((option) => option.department)
                    .toList(growable: false),
                onChanged: onDepartmentChanged,
                validator: (value) =>
                    requiredValidator(value, 'College or department'),
              ),
              const SizedBox(height: 7),
              _SignupDropdownField(
                label: 'Course or Program',
                icon: Icons.school_outlined,
                value: selectedCourse,
                items: selectedCourses,
                onChanged: selectedDepartment == null ? null : onCourseChanged,
                validator: (value) =>
                    requiredValidator(value, 'Course or program'),
              ),
            ],
            const SizedBox(height: 7),
            _SignupField(
              controller: passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: (value) => requiredValidator(value, 'Password'),
            ),
            const SizedBox(height: 7),
            _SignupField(
              controller: confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: confirmPasswordValidator,
            ),
            const SizedBox(height: 9),
            _TermsCheckbox(
              acceptedTerms: acceptedTerms,
              onChanged: onTermsChanged,
            ),
            const SizedBox(height: 23),
            _SignUpButton(onPressed: isLoading ? null : onSignUp),
          ],
        ),
      ),
    );
  }
}

class _SignupField extends StatelessWidget {
  const _SignupField({
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final iconData = icon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 11, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              color: _SignupColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          validator: validator,
          cursorColor: _SignupColors.button,
          style: const TextStyle(
            color: _SignupColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: label,
            hintStyle: const TextStyle(
              color: _SignupColors.hintText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            prefixIcon: iconData == null
                ? null
                : _SignupFieldIcon(icon: iconData),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            errorStyle: const TextStyle(
              fontSize: 9,
              height: 0.9,
              fontWeight: FontWeight.w700,
              color: _SignupColors.error,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _SignupColors.fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _SignupColors.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: _SignupColors.button,
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _SignupColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: _SignupColors.error,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignupDropdownField extends StatelessWidget {
  const _SignupDropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.validator,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 11, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              color: _SignupColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: effectiveValue,
          isExpanded: true,
          items: [
            for (final item in items)
              DropdownMenuItem<String>(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
          validator: validator,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          style: const TextStyle(
            color: _SignupColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: onChanged == null
                ? const Color(0xFFF7F1E6)
                : Colors.white,
            hintText: onChanged == null ? 'Select college first' : label,
            hintStyle: const TextStyle(
              color: _SignupColors.hintText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            prefixIcon: Icon(icon, size: 18, color: _SignupColors.text),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            errorStyle: const TextStyle(
              fontSize: 9,
              height: 0.9,
              fontWeight: FontWeight.w700,
              color: _SignupColors.error,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _SignupColors.fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _SignupColors.fieldBorder),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _SignupColors.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: _SignupColors.button,
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _SignupColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: _SignupColors.error,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignupFieldIcon extends StatelessWidget {
  const _SignupFieldIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Icon(icon, size: 18, color: _SignupColors.text),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.acceptedTerms, required this.onChanged});

  final bool acceptedTerms;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: acceptedTerms,
            onChanged: onChanged,
            activeColor: _SignupColors.button,
            checkColor: _SignupColors.text,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: const BorderSide(color: _SignupColors.text, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        const Expanded(
          child: Text(
            'I accept Privacy & Term of Use',
            style: TextStyle(
              color: _SignupColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignUpButton extends StatelessWidget {
  const _SignUpButton({required this.onPressed});

  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _SignupColors.button,
          foregroundColor: _SignupColors.text,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        child: onPressed == null
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _SignupColors.text,
                ),
              )
            : const Text('Sign Up'),
      ),
    );
  }
}

class _BubbleCluster extends StatelessWidget {
  const _BubbleCluster({this.top, this.left, this.right, required this.mirror});

  final double? top;
  final double? left;
  final double? right;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    const bubbles = [
      _BubbleSpec(23, 0, 30, _SignupColors.bubbleYellow),
      _BubbleSpec(52, 29, 29, _SignupColors.bubbleGray),
      _BubbleSpec(9, 30, 23, _SignupColors.bubbleYellow),
      _BubbleSpec(66, 38, 24, _SignupColors.bubbleYellow),
      _BubbleSpec(35, 52, 20, _SignupColors.bubbleGray),
      _BubbleSpec(0, 62, 26, _SignupColors.bubbleGray),
      _BubbleSpec(53, 73, 24, _SignupColors.bubbleYellow),
      _BubbleSpec(82, 80, 14, _SignupColors.bubbleYellow),
      _BubbleSpec(28, 98, 17, _SignupColors.bubbleGray),
      _BubbleSpec(51, 127, 20, _SignupColors.bubbleYellow),
    ];

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.scale(
        scaleX: mirror ? -1 : 1,
        child: SizedBox(
          width: 118,
          height: 153,
          child: Stack(
            clipBehavior: Clip.none,
            children: [for (final bubble in bubbles) _Bubble(spec: bubble)],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.spec});

  final _BubbleSpec spec;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: spec.left,
      top: spec.top,
      child: Container(
        width: spec.size,
        height: spec.size,
        decoration: BoxDecoration(
          color: spec.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 7,
              offset: const Offset(4, 5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleSpec {
  const _BubbleSpec(this.left, this.top, this.size, this.color);

  final double left;
  final double top;
  final double size;
  final Color color;
}

class _CollegeCourseOption {
  const _CollegeCourseOption({required this.department, required this.courses});

  final String department;
  final List<String> courses;
}

List<String> _coursesForDepartment(String? department) {
  if (department == null) return const [];
  for (final option in _collegeCourseOptions) {
    if (option.department == department) return option.courses;
  }
  return const [];
}

const _sectorOptions = [
  'Administration',
  'Registrar',
  'Finance',
  'Library',
  'Guidance/PACC',
  'Health Services',
  'IT/MIS',
  'Maintenance/Facilities',
  'Security',
  'Other',
];

const _collegeCourseOptions = [
  _CollegeCourseOption(
    department: 'College of Accountancy and Business Administration',
    courses: ['BS Accountancy', 'BS Business Administration', 'BS Management'],
  ),
  _CollegeCourseOption(
    department: 'College of Arts and Sciences / College of Arts and Languages',
    courses: [
      'BA Communication / Mass Communication',
      'BA English',
      'BA Filipino',
      'BA Political Science',
      'BA Psychology',
    ],
  ),
  _CollegeCourseOption(
    department:
        'College of Information and Technology Education / College of Computer Studies',
    courses: [
      'BS Information Technology',
      'Bachelor of Library and Information Science',
      'Associate in Computer Technology',
    ],
  ),
  _CollegeCourseOption(
    department: 'College of Criminology',
    courses: ['BS Criminology'],
  ),
  _CollegeCourseOption(
    department: 'College of Education / College of Teacher Education',
    courses: [
      'Bachelor of Elementary Education - Preschool Ed, Primary Ed',
      'Bachelor of Secondary Education - English, Filipino, Mathematics, Science, Social Studies',
      'Bachelor in Physical Education',
      'Bachelor in Music',
      'Bachelor in Fine Arts',
    ],
  ),
  _CollegeCourseOption(
    department: 'College of Engineering and Architecture',
    courses: [
      'BS Architecture',
      'BS Civil Engineering',
      'BS Computer Engineering',
      'BS Electrical Engineering / Electronic Engineering',
      'BS Mechanical Engineering',
    ],
  ),
  _CollegeCourseOption(department: 'College of Law', courses: ['Juris Doctor']),
  _CollegeCourseOption(
    department: 'College of Nursing',
    courses: ['BS Nursing'],
  ),
  _CollegeCourseOption(
    department: 'College of Pharmacy',
    courses: ['BS Pharmacy'],
  ),
  _CollegeCourseOption(
    department: 'College of Science and Mathematics',
    courses: ['BS Mathematics', 'BS Biology / Natural Sciences'],
  ),
  _CollegeCourseOption(
    department: 'College of Social Work',
    courses: ['BS Social Work'],
  ),
  _CollegeCourseOption(
    department: 'Graduate School / Institute of Graduate and Advanced Studies',
    courses: [
      'Doctor of Education',
      'Master of Arts in Education - all major fields',
      'Master in Business Administration',
      'Master of Arts in Nursing',
    ],
  ),
  _CollegeCourseOption(
    department:
        'School of Hotel and Restaurant Services and Tourism Management',
    courses: ['BS Hotel and Restaurant Management', 'BS Tourism Management'],
  ),
  _CollegeCourseOption(
    department: 'School of Midwifery',
    courses: ['Midwifery Program'],
  ),
];

class _SignupColors {
  const _SignupColors._();

  static const background = Color(0xFFFEFEFE);
  static const card = Color(0xFFFFE9AC);
  static const notice = Color(0xFFFFE292);
  static const button = Color(0xFFFFBE0A);
  static const text = Color(0xFF050505);
  static const hintText = Color(0xFF6C6250);
  static const fieldBorder = Color(0xFF8A7350);
  static const error = Color(0xFFB3261E);
  static const bubbleYellow = Color(0xFFFFCF52);
  static const bubbleGray = Color(0xFFD9D9D9);
}
