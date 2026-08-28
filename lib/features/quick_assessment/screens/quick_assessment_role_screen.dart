import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../routes/route_names.dart';
import '../models/quick_assessment_models.dart';
import '../widgets/quick_assessment_widgets.dart';

class QuickAssessmentRoleScreen extends StatelessWidget {
  const QuickAssessmentRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final user = context.watch<UserProvider>().user;
      if (user?.quickAssessmentCompleted == true) {
        return const _CompletedAssessmentRedirect();
      }
      final storedRole = user?.assessmentRole;
      if (storedRole != null) return _StoredRoleRedirect(role: storedRole);
    } on ProviderNotFoundException {
      // Standalone previews can render without authentication state.
    }

    return QuickAssessmentScaffold(
      showBottomBubble: false,
      topClusters: const [],
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              108,
              24,
              26 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 134,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: const _RoleContent(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoredRoleRedirect extends StatefulWidget {
  const _StoredRoleRedirect({required this.role});

  final AssessmentRole role;

  @override
  State<_StoredRoleRedirect> createState() => _StoredRoleRedirectState();
}

class _StoredRoleRedirectState extends State<_StoredRoleRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AssessmentProvider>().selectRole(widget.role);
      Navigator.of(
        context,
      ).pushReplacementNamed(RouteNames.quickAssessmentName);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _CompletedAssessmentRedirect extends StatefulWidget {
  const _CompletedAssessmentRedirect();

  @override
  State<_CompletedAssessmentRedirect> createState() =>
      _CompletedAssessmentRedirectState();
}

class _CompletedAssessmentRedirectState
    extends State<_CompletedAssessmentRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _RoleContent extends StatelessWidget {
  const _RoleContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Adaptive Mental Health\nAssessment',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: QuickAssessmentPalette.text,
            fontSize: 27,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'First, please select your role within the institution to\nget personalized questions',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: QuickAssessmentPalette.text,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        _RoleCard(
          role: AssessmentRole.student,
          icon: Icons.school_outlined,
          onTap: () => _selectRole(context, AssessmentRole.student),
        ),
        const SizedBox(height: 16),
        _RoleCard(
          role: AssessmentRole.faculty,
          icon: Icons.co_present_outlined,
          onTap: () => _selectRole(context, AssessmentRole.faculty),
        ),
        const SizedBox(height: 16),
        _RoleCard(
          role: AssessmentRole.staff,
          icon: Icons.badge_outlined,
          onTap: () => _selectRole(context, AssessmentRole.staff),
        ),
        const SizedBox(height: 32),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Your responses are handled securely and used to provide your assessment experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: QuickAssessmentPalette.mutedText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _selectRole(BuildContext context, AssessmentRole role) {
    context.read<AssessmentProvider>().selectRole(role);
    Navigator.of(context).pushNamed(RouteNames.quickAssessmentName);
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.onTap,
  });

  final AssessmentRole role;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBEC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 98),
          padding: const EdgeInsets.fromLTRB(15, 16, 8, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: QuickAssessmentPalette.primary),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: QuickAssessmentPalette.softBorder,
                child: Icon(icon, color: QuickAssessmentPalette.text),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: const TextStyle(
                        color: QuickAssessmentPalette.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      role.description,
                      style: const TextStyle(
                        color: QuickAssessmentPalette.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: QuickAssessmentPalette.text,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
