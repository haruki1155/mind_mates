# Assessment policy

The Full Assessment's five-point agreement response scale was confirmed by the
licensed psychologist who approved the questionnaire: Strongly Disagree,
Disagree, Neutral, Agree, Strongly Agree. This is distinct from clinical
validation; the assessment must not be represented as clinically validated.

The canonical server implementation is `functions/src/assessment/`; the Dart policy copy exists only for local question flow and regression parity. New final results are calculated by Firebase Functions.

| Rule | Current value | Purpose | Source | Evidence status | Action | Remaining review |
|---|---:|---|---|---|---|---|
| Full question set | `experimental_role_based_v2_agreement` | Student, teaching, and non-teaching wellness prompts with the approved agreement response scale | Licensed psychologist-approved response scale; question wording retained | Response scale confirmed; other scoring rules require separate approval | Versioned response-scale correction | Item-by-item scoring and interpretation review |
| Quick question set | `experimental_quick_v1` | Five-item onboarding awareness screen | Repository product configuration | Unsupported/source not found | Retained and relabeled | Professional review; do not present as a validated short form |
| Scoring policy | `internal_wellness_policy_v1` | Normalize answers and classify estimates | Repository product configuration | Internally defined product rule | Centralized | Professional review |
| Likert normalization | Risk `(answer-1)/4*100`; protective `(5-answer)/4*100` | Common 0–100 concern direction | Repository implementation | Internally defined product rule | Retained | Professional review |
| Domain completion | At least 3 answers and 70% of core items | Suppress sparse category estimates | Repository implementation | Internally defined product rule | Centralized | Psychometric review |
| Response confidence | High ≥90%; caution ≥70%; otherwise limited | Describe completeness, not validity | Repository implementation | Internally defined product rule | Centralized and disclosed | Rename/review to avoid implying statistical confidence |
| Concern bands | ≤20 low; ≤40 watchful; ≤60 moderate; ≤80 elevated; >80 high | Human-readable score ranges | Repository implementation | Internally defined product rule | Retained and centralized | Professional review |
| Quick bands | ≥75 very high; ≥55 high; ≥30 moderate; otherwise low | Quick-screen summary | Repository implementation | Internally defined product rule | Retained and centralized | Professional review |
| Conditional questions | Show when ≥1 Strongly Agree, ≥2 Agree/Strongly Agree, or core mean ≥50 | Collect contextual follow-up | Repository implementation | Internally defined product rule | Retained and centralized | Professional review |
| Main concern area | Domain score >60 | Rank focus areas | Repository implementation | Internally defined product rule | Retained | Professional review |
| Prompt follow-up | Any domain >80, two >60, or ≥3 functional-impact flags | Suggest timely direct support | Repository implementation | Requires professional review | Retained and disclosed | Licensed professional approval |
| Follow-up suggested | Any domain >60, two >40, or ≥2 functional-impact flags | Suggest optional conversation | Repository implementation | Requires professional review | Retained and disclosed | Licensed professional approval |
| Monitor | Any domain >40 or ≥1 functional-impact flag | Suggest monitoring | Repository implementation | Requires professional review | Retained and disclosed | Licensed professional approval |

## Domain weights

All weights are internal product rules with no documented source and require professional review.

| Population | Domain weights |
|---|---|
| Student | Academic Stress 25%; Financial Well-Being 15%; Social Adjustment 10%; Sleep and Rest 20%; Emotional Well-Being 30% |
| Teaching | Workplace Stress 30%; Professional Support 15%; Professional Well-Being 15%; Sleep and Rest 15%; Emotional Well-Being 25% |
| Non-teaching | Workplace Responsibilities 30%; Workplace Support 15%; Workplace Well-Being 15%; Sleep and Rest 15%; Emotional Well-Being 25% |

Question groups are academic/workplace core and conditional follow-up, financial or workplace support, social/professional well-being, sleep/rest, and emotional well-being. No repository evidence establishes validity, reliability, sensitivity, specificity, or clinical endorsement for any group.
