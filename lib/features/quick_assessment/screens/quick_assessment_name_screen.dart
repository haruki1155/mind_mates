import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../routes/route_names.dart';
import '../widgets/quick_assessment_widgets.dart';

class QuickAssessmentNameScreen extends StatefulWidget {
  const QuickAssessmentNameScreen({super.key});

  @override
  State<QuickAssessmentNameScreen> createState() =>
      _QuickAssessmentNameScreenState();
}

class _QuickAssessmentNameScreenState extends State<QuickAssessmentNameScreen> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<AssessmentProvider>().name,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuickAssessmentScaffold(
      topClusters: const [],
      showBottomBubble: false,
      child: Column(
        children: [
          const QuickProgressHeader(step: 0, label: 'Setup'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    52,
                    92,
                    56,
                    112 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 206,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        const Text(
                          'Enter Your Name',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: QuickAssessmentPalette.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _NameField(
                          controller: _controller,
                          errorText: _errorText,
                          onSubmitted: _submit,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: 48 + MediaQuery.paddingOf(context).bottom,
            ),
            child: QuickNextButton(onPressed: _submit),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final provider = context.read<AssessmentProvider>();
    provider.updateName(_controller.text);

    if (!provider.isNameValid) {
      setState(() => _errorText = 'Please enter your name to continue.');
      return;
    }

    setState(() => _errorText = null);

    provider.resetQuestions();
    Navigator.of(context).pushNamed(RouteNames.quickAssessmentQuestions);
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Name',
          style: TextStyle(
            color: QuickAssessmentPalette.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textAlign: TextAlign.left,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          onChanged: (value) {
            context.read<AssessmentProvider>().updateName(value);
          },
          onSubmitted: (_) => onSubmitted(),
          style: const TextStyle(
            color: QuickAssessmentPalette.text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            errorText: errorText,
            hintStyle: TextStyle(
              color: QuickAssessmentPalette.text.withValues(alpha: 0.82),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
            filled: true,
            fillColor: QuickAssessmentPalette.cream,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: QuickAssessmentPalette.softBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: QuickAssessmentPalette.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
