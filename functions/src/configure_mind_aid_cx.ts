import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {FlowsClient, IntentsClient, SessionsClient, protos} from "@google-cloud/dialogflow-cx";

import {
  mindAidCxFallback,
  mindAidCxDialogueCases,
  mindAidCxFlows,
  mindAidCxIntents,
  mindAidCxRedTeamCases,
  mindAidCxWelcome,
} from "./mind_aid_cx_spec";

type DatasetRecord = {intent: string; responses?: string[]};

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "mindmate-dev-4e91c";
const location = process.env.DIALOGFLOW_CX_LOCATION || "asia-southeast1";
const agentId = process.env.DIALOGFLOW_CX_AGENT_ID || "";
const apply = process.argv.includes("--apply");
const runTests = process.argv.includes("--test");

if (!agentId) throw new Error("DIALOGFLOW_CX_AGENT_ID is required.");

const apiEndpoint = `${location}-dialogflow.googleapis.com`;
const clientOptions = {apiEndpoint, projectId, quotaProjectId: projectId};
const intentsClient = new IntentsClient(clientOptions);
const flowsClient = new FlowsClient(clientOptions);
const sessionsClient = new SessionsClient(clientOptions);
const agentName = `projects/${projectId}/locations/${location}/agents/${agentId}`;
const defaultFlowName = `${agentName}/flows/00000000-0000-0000-0000-000000000000`;
const defaultWelcomeIntentName = `${agentName}/intents/00000000-0000-0000-0000-000000000000`;

function loadDatasetRecords(): Map<string, DatasetRecord> {
  const records = new Map<string, DatasetRecord>();
  for (const filename of ["intents.json", "crisis_triggers.json"]) {
    const path = resolve(__dirname, "../../assets/data/mind_aid", filename);
    const parsed = JSON.parse(readFileSync(path, "utf8").replace(/^\uFEFF/, "")) as {records?: DatasetRecord[]};
    for (const record of parsed.records ?? []) records.set(record.intent, record);
  }
  return records;
}

function trainingPhrases(values: string[]): protos.google.cloud.dialogflow.cx.v3.Intent.ITrainingPhrase[] {
  return values.map((text) => ({parts: [{text}], repeatCount: 1}));
}

function valueToProto(value: unknown): protos.google.protobuf.IValue {
  if (value == null) return {nullValue: 0};
  if (typeof value === "string") return {stringValue: value};
  if (typeof value === "number") return {numberValue: value};
  if (typeof value === "boolean") return {boolValue: value};
  if (Array.isArray(value)) return {listValue: {values: value.map(valueToProto)}};
  const fields: Record<string, protos.google.protobuf.IValue> = {};
  for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
    fields[key] = valueToProto(item);
  }
  return {structValue: {fields}};
}

function fulfillment(
  text: string,
  suggestions: string[] = [],
  actions: Array<{type: string; label: string; payload?: Record<string, unknown>}> = [],
): protos.google.cloud.dialogflow.cx.v3.IFulfillment {
  return {
    messages: [
      {text: {text: [text]}},
      {payload: valueToProto({suggestions, actions}).structValue},
    ],
  };
}

function eventHandlers(
  existing: protos.google.cloud.dialogflow.cx.v3.IEventHandler[] = [],
): protos.google.cloud.dialogflow.cx.v3.IEventHandler[] {
  const names = new Map(existing.map((handler) => [handler.event, handler.name]));
  return [
    {
      name: names.get("sys.no-match-default"),
      event: "sys.no-match-default",
      triggerFulfillment: fulfillment(mindAidCxFallback),
    },
    {
      name: names.get("sys.no-input-default"),
      event: "sys.no-input-default",
      triggerFulfillment: fulfillment(
        "I'm still here. You can tell me whether this is about school, work, relationships, sleep, stress, your assessment, or something else.",
      ),
    },
  ];
}

async function ensureFlows(): Promise<Map<string, string>> {
  const [existing] = await flowsClient.listFlows({parent: agentName, pageSize: 100});
  const names = new Map(existing.map((flow) => [String(flow.displayName), String(flow.name)]));
  names.set("Default Start Flow", defaultFlowName);

  for (const definition of mindAidCxFlows) {
    if (names.has(definition.displayName)) continue;
    console.log(`${apply ? "CREATE" : "WOULD CREATE"} flow: ${definition.displayName}`);
    if (!apply) continue;
    const [created] = await flowsClient.createFlow({
      parent: agentName,
      flow: {
        displayName: definition.displayName,
        description: definition.description,
        nluSettings: {modelType: "MODEL_TYPE_ADVANCED", classificationThreshold: 0.4},
      },
      languageCode: "en",
    });
    names.set(definition.displayName, String(created.name));
  }
  return names;
}

async function ensureIntents(): Promise<Map<string, string>> {
  const [existing] = await intentsClient.listIntents({parent: agentName, pageSize: 100, languageCode: "en"});
  const byDisplayName = new Map(existing.map((intent) => [String(intent.displayName), intent]));

  if (!byDisplayName.has("Default Welcome Intent")) throw new Error("Default Welcome Intent is missing.");
  console.log(`${apply ? "UPDATE" : "WOULD UPDATE"} intent: Default Welcome Intent`);
  if (apply) {
    await intentsClient.updateIntent({
      intent: {
        name: defaultWelcomeIntentName,
        displayName: "Default Welcome Intent",
        trainingPhrases: trainingPhrases(mindAidCxWelcome.trainingPhrases),
        priority: 500000,
      },
      languageCode: "en",
      updateMask: {paths: ["training_phrases"]},
    });
  }

  const names = new Map<string, string>();
  for (const definition of mindAidCxIntents) {
    const current = byDisplayName.get(definition.displayName);
    const verb = current ? "UPDATE" : "CREATE";
    console.log(`${apply ? verb : `WOULD ${verb}`} intent: ${definition.displayName}`);
    const intent = {
      name: current?.name,
      displayName: definition.displayName,
      description: `MindAid reviewed route for ${definition.flow}.`,
      trainingPhrases: trainingPhrases(definition.trainingPhrases),
      priority: 500000,
    };
    if (!apply) {
      if (current?.name) names.set(definition.displayName, String(current.name));
      continue;
    }
    if (current?.name) {
      await intentsClient.updateIntent({
        intent,
        languageCode: "en",
        updateMask: {paths: ["display_name", "description", "training_phrases", "priority"]},
      });
      names.set(definition.displayName, String(current.name));
    } else {
      const [created] = await intentsClient.createIntent({parent: agentName, intent, languageCode: "en"});
      names.set(definition.displayName, String(created.name));
    }
  }
  return names;
}

async function configureFlowRoutes(
  flowNames: Map<string, string>,
  intentNames: Map<string, string>,
): Promise<void> {
  if (!apply) {
    console.log("WOULD UPDATE reviewed routes and fallback handlers on every MindAid flow.");
    return;
  }
  const dataset = loadDatasetRecords();
  const managedFlowNames = [
    defaultFlowName,
    ...mindAidCxFlows.map((flow) => flowNames.get(flow.displayName)),
  ].filter((name): name is string => Boolean(name));

  for (const flowName of managedFlowNames) {
    const [flow] = await flowsClient.getFlow({name: flowName, languageCode: "en"});
    const existingRoutes = new Map((flow.transitionRoutes ?? []).map((route) => [String(route.intent), route]));
    const routes: protos.google.cloud.dialogflow.cx.v3.ITransitionRoute[] = [];

    if (flowName === defaultFlowName) {
      const currentWelcome = existingRoutes.get(defaultWelcomeIntentName);
      routes.push({
        name: currentWelcome?.name,
        intent: defaultWelcomeIntentName,
        triggerFulfillment: fulfillment(mindAidCxWelcome.response),
        targetFlow: flowNames.get("MindAid General Support"),
      });
    }

    for (const definition of mindAidCxIntents) {
      const intentName = intentNames.get(definition.displayName);
      if (!intentName) throw new Error(`Missing intent resource: ${definition.displayName}`);
      const record = definition.datasetIntent ? dataset.get(definition.datasetIntent) : undefined;
      const response = definition.response ?? record?.responses?.[0];
      if (!response) throw new Error(`Missing reviewed response: ${definition.displayName}`);
      const targetFlow = flowNames.get(definition.flow);
      if (!targetFlow) throw new Error(`Missing target flow: ${definition.flow}`);
      const isDestinationFlow = flowName === targetFlow;
      routes.push({
        name: existingRoutes.get(intentName)?.name,
        intent: intentName,
        triggerFulfillment: isDestinationFlow
          ? fulfillment(response, definition.suggestions, definition.actions)
          : undefined,
        targetFlow: isDestinationFlow ? undefined : targetFlow,
      });
    }

    console.log(`UPDATE flow routes: ${flow.displayName}`);
    await flowsClient.updateFlow({
      flow: {
        name: flow.name,
        displayName: flow.displayName,
        description: flow.description,
        transitionRoutes: routes,
        eventHandlers: eventHandlers(flow.eventHandlers ?? []),
        nluSettings: {modelType: "MODEL_TYPE_ADVANCED", classificationThreshold: 0.4},
      },
      languageCode: "en",
      updateMask: {paths: ["transition_routes", "event_handlers", "nlu_settings"]},
    });
  }
}

async function runRedTeamTests(): Promise<void> {
  if (!apply) throw new Error("Use --apply --test so tests run against synchronized resources.");
  let failed = 0;
  for (const [index, testCase] of mindAidCxRedTeamCases.entries()) {
    const session = sessionsClient.projectLocationAgentSessionPath(
      projectId,
      location,
      agentId,
      `cx-review-${Date.now()}-${index}`,
    );
    const [response] = await sessionsClient.detectIntent({
      session,
      queryInput: {text: {text: testCase.text}, languageCode: "en"},
    });
    const actualIntent = String(response.queryResult?.match?.intent?.displayName ?? "NO_MATCH");
    const text = (response.queryResult?.responseMessages ?? [])
      .flatMap((message) => message.text?.text ?? [])
      .join(" ")
      .trim();
    const passed = actualIntent === testCase.expectedIntent && text.length > 0;
    if (!passed) failed += 1;
    console.log(`${passed ? "PASS" : "FAIL"} ${JSON.stringify(testCase.text)} -> ${actualIntent}`);
  }
  for (const [caseIndex, dialogue] of mindAidCxDialogueCases.entries()) {
    const session = sessionsClient.projectLocationAgentSessionPath(
      projectId,
      location,
      agentId,
      `cx-dialogue-${Date.now()}-${caseIndex}`,
    );
    for (const [turnIndex, turn] of dialogue.turns.entries()) {
      const [response] = await sessionsClient.detectIntent({
        session,
        queryInput: {text: {text: turn.text}, languageCode: "en"},
      });
      const actualIntent = String(response.queryResult?.match?.intent?.displayName ?? "NO_MATCH");
      const responseText = (response.queryResult?.responseMessages ?? [])
        .flatMap((message) => message.text?.text ?? [])
        .join(" ")
        .trim();
      const passed = actualIntent === turn.expectedIntent && responseText.length > 0;
      if (!passed) failed += 1;
      console.log(
        `${passed ? "PASS" : "FAIL"} dialogue=${JSON.stringify(dialogue.name)} ` +
        `turn=${turnIndex + 1} ${JSON.stringify(turn.text)} -> ${actualIntent}`,
      );
    }
  }
  if (failed > 0) throw new Error(`${failed} CX red-team case(s) failed.`);
}

async function main(): Promise<void> {
  console.log(`MindAid CX sync: project=${projectId} location=${location} agent=${agentId} apply=${apply}`);
  const flowNames = await ensureFlows();
  const intentNames = await ensureIntents();
  await configureFlowRoutes(flowNames, intentNames);
  if (runTests) await runRedTeamTests();
  console.log(apply ? "MindAid CX synchronization complete." : "Dry run complete. Re-run with --apply after review.");
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.stack ?? error.message : error);
  process.exitCode = 1;
});
