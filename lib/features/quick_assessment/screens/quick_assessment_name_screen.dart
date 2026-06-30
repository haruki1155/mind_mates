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
      topClusters: const [
        BubbleCluster(top: 66, left: -18),
        BubbleCluster(top: 84, right: -20, mirrored: true),
      ],
      child: Column(
        children: [
          const QuickProgressHeader(step: 1, label: '1/6'),
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
                        _NameField(controller: _controller),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name to continue.')),
      );
      return;
    }

    provider.resetQuestions();
    Navigator.of(context).pushNamed(RouteNames.quickAssessmentQuestions);
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.done,
      onChanged: context.read<AssessmentProvider>().updateName,
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
      },
      style: const TextStyle(
        color: QuickAssessmentPalette.text,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        hintText: 'Name',
        hintStyle: TextStyle(
          color: QuickAssessmentPalette.text.withValues(alpha: 0.82),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
        filled: true,
        fillColor: QuickAssessmentPalette.cream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF939393), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: QuickAssessmentPalette.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}
