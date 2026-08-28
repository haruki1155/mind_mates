import {
  FULL_ALGORITHM_VERSION,
  FULL_RESPONSE_SCALE_VERSION,
  LEGACY_FULL_ALGORITHM_VERSION,
  LEGACY_FULL_QUESTION_SET_VERSION,
  LEGACY_FULL_RESPONSE_SCALE_VERSION,
  QUICK_ALGORITHM_VERSION,
  AssessmentDirection,
  AssessmentQuestion,
  AssessmentRole,
  FULL_QUESTION_SET_VERSION,
  MIN_DOMAIN_ANSWERS,
  MIN_DOMAIN_COMPLETION,
  SCORE_BOUNDARIES,
  QUICK_BOUNDARIES,
  RESPONSE_COMPLETION,
  INDICATOR_BOUNDARIES,
  CONDITIONAL_RULE,
  FUNCTIONAL_IMPACT_QUESTION_IDS,
  PRIORITY_RULES,
  POLICY_SOURCE,
  POLICY_VALIDATION_STATUS,
  QUESTIONS_BY_ROLE,
  QUICK_QUESTION_SET_VERSION,
  QUICK_QUESTIONS,
  ROLE_DOMAINS,
  ROLE_LABELS,
} from "./catalog";

export class AssessmentValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AssessmentValidationError";
  }
}

export type FullAnswer = {questionId: string; answer: string; isSkipped: boolean};
export type QuickAnswer = {questionId: string; optionId: string; value: number};

export type Interpretation = {
  algorithmVersion: string;
  questionSetVersion: string;
  recallPeriodDays: number;
  supportPriority: string;
  priorityRationale: string;
  priorityReasonCodes: string[];
  policySource: string;
  validationStatus: string;
  supportPriorityLabel: string;
  responseQuality: Record<string, unknown>;
  domainResults: Record<string, unknown>[];
  protectiveFactors: string[];
  functionalImpactFlags: string[];
  rationale: string[];
  userSummary: string;
  counselorSummary: string;
  suggestedActions: string[];
};

const DISCLAIMER =
  "This score is an estimate from an experimental internal wellness framework. No documented validation source was found for its exact questions, weights, thresholds, or follow-up rules. It is not a diagnosis, does not confirm a mental-health condition, does not replace a licensed professional, and does not automatically alert a counselor or emergency service.";

function round(value: number): number {
  return Number(value.toFixed(2));
}

function riskScore(value: number, direction: AssessmentDirection): number {
  return direction === "protective" ? ((5 - value) / 4) * 100 : ((value - 1) / 4) * 100;
}

const agreementValues: Record<string, number> = {
  stronglyDisagree: 1,
  disagree: 2,
  neutral: 3,
  agree: 4,
  stronglyAgree: 5,
};

const legacyFrequencyValues: Record<string, number> = {
  never: 1,
  rarely: 2,
  sometimes: 3,
  often: 4,
  always: 5,
};

function valuesForResponseScale(responseScaleVersion: string): Record<string, number> {
  if (responseScaleVersion === FULL_RESPONSE_SCALE_VERSION) return agreementValues;
  if (responseScaleVersion === LEGACY_FULL_RESPONSE_SCALE_VERSION) {
    return legacyFrequencyValues;
  }
  throw new AssessmentValidationError("Unsupported full-assessment response scale.");
}

function scoreForAnswer(
  answer: string,
  direction: AssessmentDirection,
  responseScaleVersion = FULL_RESPONSE_SCALE_VERSION,
): number {
  const values = valuesForResponseScale(responseScaleVersion);
  const value = values[answer];
  if (!value) throw new AssessmentValidationError("Invalid Likert answer.");
  return riskScore(value, direction);
}

function concernBand(score: number): {name: string; label: string} {
  if (score <= SCORE_BOUNDARIES.low) return {name: "low", label: "Low"};
  if (score <= SCORE_BOUNDARIES.watchful) return {name: "watchful", label: "Watchful"};
  if (score <= SCORE_BOUNDARIES.moderate) return {name: "moderate", label: "Moderate"};
  if (score <= SCORE_BOUNDARIES.elevated) return {name: "elevated", label: "Elevated"};
  return {name: "high", label: "High"};
}

function statusFor(score: number): string {
  if (score <= SCORE_BOUNDARIES.low) return "Low Concern";
  if (score <= SCORE_BOUNDARIES.watchful) return "Watchful";
  if (score <= SCORE_BOUNDARIES.moderate) return "Moderate Concern";
  if (score <= SCORE_BOUNDARIES.elevated) return "Elevated Concern";
  return "High Concern";
}

function actionFor(domain: string, band: string): string {
  const support: Record<string, string> = {
    "Academic Stress": "review workload, deadlines, and academic support options",
    "Financial Well-Being": "review available financial-aid or student-support resources",
    "Social Adjustment": "identify one trusted person or university group you can connect with",
    "Sleep and Rest": "choose one realistic sleep or rest routine to try this week",
    "Emotional Well-Being": "continue check-ins and consider a supportive conversation",
    "Workplace Stress": "review workload priorities and available workplace support",
    "Workplace Responsibilities": "review workload priorities and available workplace support",
    "Professional Support": "identify a trusted colleague, supervisor, or university support contact",
    "Workplace Support": "identify a trusted colleague, supervisor, or university support contact",
    "Professional Well-Being": "choose one recovery or support step that feels manageable",
    "Workplace Well-Being": "choose one recovery or support step that feels manageable",
  };
  const text = support[domain] ?? "review a practical support option for this area";
  if (band === "low") return "Continue the habits and support that are working in this area.";
  if (band === "watchful") return `Monitor this area and ${text}.`;
  if (band === "moderate") return `Consider taking time to ${text}.`;
  return `Consider discussing this area with university wellness support and ${text}.`;
}

function shouldShowDeeper(
  questions: AssessmentQuestion[],
  answers: FullAnswer[],
  responseScaleVersion = FULL_RESPONSE_SCALE_VERSION,
): boolean {
  const riskCore = questions.filter((question) => !question.conditional && question.direction === "risk" &&
    ["academicCore", "workplaceStressCore", "workplaceResponsibilityCore"].includes(question.section));
  const byId = new Map(answers.map((answer) => [answer.questionId, answer]));
  const scored = riskCore
    .map((question) => ({question, answer: byId.get(question.id)}))
    .filter((item): item is {question: AssessmentQuestion; answer: FullAnswer} => Boolean(item.answer && !item.answer.isSkipped));
  const maximum = responseScaleVersion === FULL_RESPONSE_SCALE_VERSION ? "stronglyAgree" : "always";
  const high = responseScaleVersion === FULL_RESPONSE_SCALE_VERSION ? "agree" : "often";
  const stronglyAgree = scored.filter((item) => item.answer.answer === maximum).length;
  const agreeOrStronglyAgree = scored.filter((item) => item.answer.answer === high || item.answer.answer === maximum).length;
  const average = scored.length === 0 ? 0 : scored.reduce((total, item) => total + scoreForAnswer(item.answer.answer, item.question.direction, responseScaleVersion), 0) / scored.length;
  return stronglyAgree >= CONDITIONAL_RULE.stronglyAgree ||
    agreeOrStronglyAgree >= CONDITIONAL_RULE.agreeOrStronglyAgree ||
    average >= CONDITIONAL_RULE.average;
}

function quality(presented: number, answers: FullAnswer[]) {
  const answered = answers.filter((answer) => !answer.isSkipped).length;
  const skipped = answers.length - answered;
  const completionPercent = presented === 0 ? 0 : round((answered / presented) * 100);
  const confidence = completionPercent >= RESPONSE_COMPLETION.high ? "high" : completionPercent >= RESPONSE_COMPLETION.usable ? "usableWithCaution" : "limited";
  const confidenceLabel = confidence === "high" ? "High confidence" : confidence === "usableWithCaution" ? "Usable with caution" : "Limited responses";
  return {presented, answered, skipped, completionPercent, confidence, confidenceLabel};
}

export function calculateFull(
  role: AssessmentRole,
  answers: FullAnswer[],
  responseScaleVersion = FULL_RESPONSE_SCALE_VERSION,
): Record<string, unknown> {
  const algorithmVersion = responseScaleVersion === LEGACY_FULL_RESPONSE_SCALE_VERSION
    ? LEGACY_FULL_ALGORITHM_VERSION
    : FULL_ALGORITHM_VERSION;
  const questionSetVersion = responseScaleVersion === LEGACY_FULL_RESPONSE_SCALE_VERSION
    ? LEGACY_FULL_QUESTION_SET_VERSION
    : FULL_QUESTION_SET_VERSION;
  const questions = QUESTIONS_BY_ROLE[role];
  const byId = new Map(answers.map((answer) => [answer.questionId, answer]));
  const showDeeper = shouldShowDeeper(questions, answers, responseScaleVersion);
  const presented = questions.filter((question) => !question.conditional || showDeeper);
  const expectedIds = new Set(presented.map((question) => question.id));
  if (answers.some((answer) => !expectedIds.has(answer.questionId))) throw new AssessmentValidationError("Answers do not match the active question set.");

  const domainScores: Record<string, number> = {};
  const domainScorable: Record<string, boolean> = {};
  const domainResults: Record<string, unknown>[] = [];
  const elevatedByDomain = new Map<string, string[]>();
  const protectiveByDomain = new Map<string, string[]>();
  const functionalFlags: string[] = [];

  for (const question of presented) {
    const answer = byId.get(question.id);
    if (!answer || answer.isSkipped) continue;
    const score = scoreForAnswer(answer.answer, question.direction, responseScaleVersion);
    if (score >= INDICATOR_BOUNDARIES.elevated) {
      const values = elevatedByDomain.get(question.domain) ?? [];
      values.push(question.text);
      elevatedByDomain.set(question.domain, values);
      if (FUNCTIONAL_IMPACT_QUESTION_IDS.has(question.id)) functionalFlags.push(question.text);
    }
    if (question.direction === "protective" && score <= INDICATOR_BOUNDARIES.protectiveMaximum) {
      const values = protectiveByDomain.get(question.domain) ?? [];
      values.push(question.text);
      protectiveByDomain.set(question.domain, values);
    }
  }

  for (const domain of ROLE_DOMAINS[role]) {
    const domainQuestions = questions.filter((question) => domain.sections.includes(question.section) && !question.conditional);
    const scores = domainQuestions
      .map((question) => byId.get(question.id))
      .filter((answer): answer is FullAnswer => Boolean(answer && !answer.isSkipped))
      .map((answer) => {
        const question = domainQuestions.find((item) => item.id === answer.questionId)!;
        return scoreForAnswer(answer.answer, question.direction, responseScaleVersion);
      });
    const completionPercent = domainQuestions.length === 0 ? 0 : round((scores.length / domainQuestions.length) * 100);
    const scorable = scores.length >= MIN_DOMAIN_ANSWERS && scores.length / domainQuestions.length >= MIN_DOMAIN_COMPLETION;
    const score = scorable ? round(scores.reduce((a, b) => a + b, 0) / scores.length) : 0;
    domainScorable[domain.label] = scorable;
    if (scorable) domainScores[domain.label] = score;
    const band = scorable ? concernBand(score) : {name: "insufficient", label: "Insufficient responses"};
    domainResults.push({
      domain: domain.label,
      score,
      band: band.name,
      bandLabel: band.label,
      answeredCount: scores.length,
      skippedCount: domainQuestions.length - scores.length,
      presentedCount: domainQuestions.length,
      completionPercent,
      isScorable: scorable,
      interpretation: scorable
        ? `${domain.label} responses currently show a ${band.label.toLowerCase()} concern pattern.`
        : `${domain.label} needs more answered questions before a dependable category result can be shown.`,
      suggestedAction: scorable ? actionFor(domain.label, band.name) : `Answer more ${domain.label.toLowerCase()} questions when you feel comfortable, or discuss this area directly with a counselor.`,
      elevatedIndicators: elevatedByDomain.get(domain.label) ?? [],
      protectiveIndicators: protectiveByDomain.get(domain.label) ?? [],
    });
  }
  const weightByDomain = new Map(ROLE_DOMAINS[role].map((domain) => [domain.label, domain.weight]));
  domainResults.sort((a, b) => {
    const scoreOrder = Number(b.score) - Number(a.score);
    if (scoreOrder !== 0) return scoreOrder;
    const weightOrder = (weightByDomain.get(String(b.domain)) ?? 0) - (weightByDomain.get(String(a.domain)) ?? 0);
    if (weightOrder !== 0) return weightOrder;
    return String(a.domain).localeCompare(String(b.domain));
  });

  const allScorable = Object.values(domainScorable).every(Boolean);
  const overallScore = allScorable
    ? round(ROLE_DOMAINS[role].reduce((total, domain) => total + (domainScores[domain.label] ?? 0) * domain.weight, 0))
    : null;
  const status = overallScore === null ? "Insufficient Responses" : statusFor(overallScore);
  const q = quality(presented.length, answers);
  const insufficient = q.confidence === "limited" || !allScorable;
  const scorableDomains = domainResults.filter((domain) => domain.isScorable);
  const above80 = scorableDomains.filter((domain) => Number(domain.score) > SCORE_BOUNDARIES.elevated).length;
  const above60 = scorableDomains.filter((domain) => Number(domain.score) > SCORE_BOUNDARIES.moderate).length;
  const above40 = scorableDomains.filter((domain) => Number(domain.score) > SCORE_BOUNDARIES.watchful).length;
  const priority = insufficient ? "insufficientResponses" : above80 >= PRIORITY_RULES.prompt.highDomains || above60 >= PRIORITY_RULES.prompt.elevatedDomains || functionalFlags.length >= PRIORITY_RULES.prompt.functionalImpacts
    ? "promptFollowUp" : above60 >= PRIORITY_RULES.followUp.elevatedDomains || above40 >= PRIORITY_RULES.followUp.moderateDomains || functionalFlags.length >= PRIORITY_RULES.followUp.functionalImpacts
      ? "followUpSuggested" : above40 >= PRIORITY_RULES.monitor.moderateDomains || functionalFlags.length >= PRIORITY_RULES.monitor.functionalImpacts ? "monitor" : "routine";
  const priorityLabel: Record<string, string> = {routine: "Routine monitoring", monitor: "Monitor", followUpSuggested: "Follow-up suggested", promptFollowUp: "Prompt follow-up", insufficientResponses: "Insufficient responses"};
  const priorityRationale = insufficient
    ? `Priority is limited because one or more core domains do not meet the completion rule.${functionalFlags.length ? ` ${functionalFlags.length} explicit follow-up or impact indicator${functionalFlags.length === 1 ? "" : "s"} were also recorded separately from scoring.` : ""}`
    : [
      above80 ? `${above80} domain score${above80 === 1 ? "" : "s"} above the elevated boundary` : "",
      above60 ? `${above60} domain score${above60 === 1 ? "" : "s"} above the moderate boundary` : "",
      functionalFlags.length ? `${functionalFlags.length} explicit follow-up or impact indicator${functionalFlags.length === 1 ? "" : "s"}` : "",
    ].filter(Boolean).join(", ") || "No elevated priority rule trigger was identified.";
  const priorityReasonCodes = [
    ...(insufficient ? ["insufficient_core_coverage"] : []),
    ...(above80 ? [`domain_above_80_count_${above80}`] : []),
    ...(above60 ? [`domain_above_60_count_${above60}`] : []),
    ...(above40 ? [`domain_above_40_count_${above40}`] : []),
    ...(functionalFlags.length ? [`functional_impact_count_${functionalFlags.length}`] : []),
  ];
  if (!priorityReasonCodes.length) priorityReasonCodes.push("no_elevated_priority_trigger");
  const focus = scorableDomains.filter((domain) => Number(domain.score) > INDICATOR_BOUNDARIES.focus).slice(0, 3);
  const rationale = focus.map((domain) => `${domain.domain}: ${Number(domain.score).toFixed(0)}/100 (${domain.band})`);
  if (functionalFlags.length) rationale.push(`${functionalFlags.length} response${functionalFlags.length === 1 ? "" : "s"} indicated possible day-to-day impact`);
  if (!rationale.length) rationale.push("Responses did not show a moderate or higher concern pattern");
  if (insufficient) rationale.unshift("Some categories do not have enough answered questions for a dependable overall interpretation");
  const actions: string[] = [];
  if (insufficient) actions.push("Review skipped items and complete the assessment when comfortable.", "Speak directly with a counselor if you would prefer a conversation.");
  else {
    if (scorableDomains[0]) actions.push(String(scorableDomains[0].suggestedAction));
    if (functionalFlags.length) actions.push("Review the day-to-day impact indicators separately from the domain score and choose one practical support step.");
    if (priority === "followUpSuggested" || priority === "promptFollowUp") actions.push("Consider using a locally verified counseling or qualified professional support option.");
    actions.push("Continue mood check-ins to observe changes over time.");
  }
  const focusText = focus.length ? `The main areas to review are ${focus.map((item) => item.domain).join(", ")}.` : "No wellness domain showed a moderate or higher concern pattern.";
  const opening: Record<string, string> = {
    routine: "Your responses suggest generally manageable current well-being.",
    monitor: "Your responses suggest an area that may benefit from monitoring and supportive habits.",
    followUpSuggested: "Your responses suggest notable strain that may benefit from a conversation with a counselor or trusted support person.",
    promptFollowUp: "Your responses suggest several elevated estimates under the internal framework. This does not confirm a condition; consider direct support from a qualified professional.",
    insufficientResponses: "There were not enough answered questions for a dependable interpretation.",
  };
  const interpretation: Interpretation = {
    algorithmVersion,
    questionSetVersion,
    recallPeriodDays: 14,
    supportPriority: priority,
    priorityRationale,
    priorityReasonCodes,
    policySource: POLICY_SOURCE,
    validationStatus: POLICY_VALIDATION_STATUS,
    supportPriorityLabel: priorityLabel[priority],
    responseQuality: q,
    domainResults,
    protectiveFactors: [...new Set([...protectiveByDomain.values()].flat())].slice(0, 5),
    functionalImpactFlags: [...new Set(functionalFlags)].slice(0, 5),
    rationale,
    userSummary: `${opening[priority]} ${focusText} This screening result is not a diagnosis.`,
    counselorSummary: `${ROLE_LABELS[role]} screening: ${priorityLabel[priority]}. ${focusText} Response confidence: ${q.confidenceLabel.toLowerCase()} (${q.completionPercent.toFixed(0)}% completed).`,
    suggestedActions: actions,
  };
  return {
    userType: ROLE_LABELS[role],
    overallScore,
    status,
    subscaleScores: domainScores,
    mainConcernAreas: scorableDomains.filter((domain) => Number(domain.score) > SCORE_BOUNDARIES.moderate).map((domain) => domain.domain),
    message: overallScore === null ? "Some wellness categories did not have enough responses for a dependable summary. Review the category results that are available." : status,
    disclaimer: DISCLAIMER,
    totalResponses: answers.filter((answer) => !answer.isSkipped).length,
    algorithmVersion,
    questionSetVersion,
    supportPriority: priority,
    priorityRationale,
    policySource: POLICY_SOURCE,
    validationStatus: POLICY_VALIDATION_STATUS,
    responseScaleVersion,
    interpretation,
  };
}

export function calculateQuick(role: string, name: string, answers: QuickAnswer[]): Record<string, unknown> {
  const byId = new Map(answers.map((answer) => [answer.questionId, answer]));
  if (answers.length !== QUICK_QUESTIONS.length || byId.size !== QUICK_QUESTIONS.length) throw new AssessmentValidationError("All quick assessment questions must be answered exactly once.");
  const responses = QUICK_QUESTIONS.map((question) => {
    const answer = byId.get(question.id);
    if (!answer) throw new AssessmentValidationError("Quick answers do not match the question catalog.");
    const option = question.options.find((item) => item.id === answer.optionId);
    if (!option || option.value !== answer.value) throw new AssessmentValidationError("Quick answer does not match the question catalog.");
    const min = Math.min(...question.options.map((item) => item.value));
    const max = Math.max(...question.options.map((item) => item.value));
    const concernScore = question.direction === "protective" ? ((max - answer.value) / (max - min)) * 100 : ((answer.value - min) / (max - min)) * 100;
    return {questionId: question.id, optionId: option.id, value: option.value, concernScore: round(concernScore)};
  });
  const concernScore = round(responses.reduce((total, response) => total + response.concernScore, 0) / responses.length);
  const level = concernScore >= QUICK_BOUNDARIES.veryHigh ? "veryHigh" : concernScore >= QUICK_BOUNDARIES.high ? "high" : concernScore >= QUICK_BOUNDARIES.moderate ? "moderate" : "low";
  const signal = level === "veryHigh" ? "highSupport" : level === "high" ? "elevated" : level === "moderate" ? "watchful" : "stable";
  const topConcernAreas = responses.map((response) => ({area: QUICK_QUESTIONS.find((item) => item.id === response.questionId)!.area, score: response.concernScore}))
    .filter((item) => item.score >= QUICK_BOUNDARIES.moderate)
    .sort((a, b) => b.score - a.score || a.area.localeCompare(b.area)).slice(0, 3).map((item) => item.area);
  const priority = level === "low" ? "routine" : level === "moderate" ? "monitor" : level === "high" ? "followUpSuggested" : "promptFollowUp";
  const interpretation: Interpretation = {
    algorithmVersion: QUICK_ALGORITHM_VERSION,
    questionSetVersion: QUICK_QUESTION_SET_VERSION,
    recallPeriodDays: 14,
    supportPriority: priority,
    priorityRationale: topConcernAreas.length ? `Priority is based on the quick-screen classification and the ranked areas ${topConcernAreas.join(", ")}.` : "Priority is based on the quick-screen classification; no area met the concern threshold.",
    priorityReasonCodes: ["quick_classification_" + level, ...(topConcernAreas.length ? ["ranked_quick_concern_areas"] : [])],
    policySource: POLICY_SOURCE,
    validationStatus: POLICY_VALIDATION_STATUS,
    supportPriorityLabel: priority === "routine" ? "Routine monitoring" : priority === "monitor" ? "Monitor" : priority === "followUpSuggested" ? "Follow-up suggested" : "Prompt follow-up",
    responseQuality: {presented: responses.length, answered: responses.length, skipped: 0, completionPercent: 100, confidence: "high", confidenceLabel: "High confidence"},
    domainResults: responses.map((response) => ({domain: QUICK_QUESTIONS.find((item) => item.id === response.questionId)!.area, score: response.concernScore, band: concernBand(response.concernScore).name, bandLabel: concernBand(response.concernScore).label, answeredCount: 1, skippedCount: 0, presentedCount: 1, completionPercent: 100, isScorable: true, interpretation: "This area is a wellness screening signal, not a diagnosis.", suggestedAction: "Review this area and choose one manageable support step."})),
    protectiveFactors: [],
    functionalImpactFlags: [],
    rationale: [topConcernAreas.length ? `Higher signals appeared in ${topConcernAreas.join(", ")}.` : "No quick-screen area showed a moderate concern signal."],
    userSummary: `Responses suggest a ${level} current wellness signal. This is not a diagnosis.`,
    counselorSummary: `Quick wellness screen: ${priority}. Complete the full role-based assessment for domain-level interpretation.`,
    suggestedActions: [level === "low" ? "Continue regular MindMate check-ins and wellness habits." : "Complete the full role-based assessment for more personalized insight."],
  };
  return {
    role,
    name: name.trim(),
    responses,
    concernScore,
    overallLevel: level,
    summary: interpretation.userSummary,
    topConcernAreas,
    recommendedNextStep: interpretation.suggestedActions[0],
    mentalStatusSignal: signal,
    signalSource: "quickAssessment",
    algorithmVersion: QUICK_ALGORITHM_VERSION,
    questionSetVersion: QUICK_QUESTION_SET_VERSION,
    supportPriority: priority,
    policySource: POLICY_SOURCE,
    validationStatus: POLICY_VALIDATION_STATUS,
    interpretation,
  };
}

export function activeQuestions(
  role: AssessmentRole,
  answers: FullAnswer[],
  responseScaleVersion = FULL_RESPONSE_SCALE_VERSION,
): AssessmentQuestion[] {
  const questions = QUESTIONS_BY_ROLE[role];
  return questions.filter((question) => !question.conditional || shouldShowDeeper(questions, answers, responseScaleVersion));
}

export function validateFullAnswers(
  role: AssessmentRole,
  answers: FullAnswer[],
  responseScaleVersion = FULL_RESPONSE_SCALE_VERSION,
): void {
  if (!Array.isArray(answers) || answers.length === 0 || answers.length > 60) throw new AssessmentValidationError("A valid answer list is required.");
  if (new Set(answers.map((answer) => answer.questionId)).size !== answers.length) throw new AssessmentValidationError("Duplicate question IDs are not allowed.");
  const questions = QUESTIONS_BY_ROLE[role];
  const questionById = new Map(questions.map((question) => [question.id, question]));
  const responseValues = valuesForResponseScale(responseScaleVersion);
  for (const answer of answers) {
    const question = questionById.get(answer.questionId);
    if (!question || typeof answer.answer !== "string" || !(answer.answer in responseValues) || typeof answer.isSkipped !== "boolean") throw new AssessmentValidationError("Invalid full-assessment answer.");
  }
  const expected = new Set(activeQuestions(role, answers, responseScaleVersion).map((question) => question.id));
  if (answers.some((answer) => !expected.has(answer.questionId)) || answers.length !== expected.size) throw new AssessmentValidationError("Answers do not match the active question set.");
}

export function validateQuickAnswers(answers: QuickAnswer[]): void {
  if (!Array.isArray(answers) || answers.length !== QUICK_QUESTIONS.length || new Set(answers.map((answer) => answer.questionId)).size !== answers.length) throw new AssessmentValidationError("All quick assessment questions must be answered exactly once.");
}
