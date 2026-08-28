# MindAid Dialogflow CX Operations

This runbook makes MindAid's dialogue flow repeatable and keeps the Firebase
Function authoritative. The Flutter app never calls Dialogflow CX directly.

## Current architecture

1. Flutter classifies explicit safety language locally so a crisis response
   does not depend on a network call.
2. For an eligible pilot user, Flutter calls the authenticated
   `sendMindAidMessage` Firebase callable.
3. The Function repeats the safety check, validates consent, request shape,
   rollout eligibility, rate limits, and context, then calls Dialogflow CX.
4. Dialogflow CX matches a reviewed intent and returns deterministic text and
   optional allowlisted actions.
5. The Function treats a high-confidence `safety.*` CX intent as controlled
   safety content and applies the output guardrails before returning anything
   to Flutter.
6. Flutter ignores unknown action types and falls back to its local engine if
   the cloud path is unavailable.

## Reviewed flow map

| Flow | Purpose | Response mode |
| --- | --- | --- |
| Default Start Flow | Welcome and global routing | Deterministic |
| MindAid General Support | Capabilities, thanks, goodbye, general support | Deterministic |
| Academic Support | Academic stress, exam anxiety, finances, burnout | Approved dataset |
| Mood and Coping | Loneliness, sleep, grounding, brief coping | Approved dataset |
| Assessment Support | Non-diagnostic result support | Approved dataset |
| Counseling Handoff | PACC/support-services action | Approved dataset |
| Crisis Safety | Self-harm, immediate danger, abuse, severe panic | Approved static safety responses; no generator or webhook |

The source of truth is `functions/src/mind_aid_cx_spec.ts`. Dataset-backed
responses are resolved from `assets/data/mind_aid/intents.json` and
`assets/data/mind_aid/crisis_triggers.json`. The synchronization script does
not modify approved question wording or assessment scoring.

## Step 1: Review a proposed dialogue change

Before editing the CX console, update the source specification. For every new
intent, review:

- the exact intent name and destination flow;
- English and Taglish training phrases;
- whether phrases overlap another intent;
- the approved response source;
- any action, which must be in the client allowlist;
- safety escalation and false-positive risks.

For clinical or safety wording, obtain the required psychologist/counselor and
institutional approval before pilot use. Never use raw production messages,
private mood notes, assessment answers, or contact details as training data.

## Step 2: Preview and synchronize the agent

From the repository root:

```powershell
cd functions
npm run mindaid:cx:dry-run
npm run mindaid:cx:apply
```

The first command shows which resources would be created or updated. The
second command applies the same version-controlled specification. Re-running
it is expected and should update existing resources rather than duplicate
them.

## Step 3: Run automated validation

```powershell
cd functions
npm run build
node --test lib/mind_aid_cx_spec.test.js lib/mind_aid.test.js
npm run mindaid:cx:test
cd ..
flutter analyze lib/features/mind_aid test/features/mind_aid/mind_aid_engine_test.dart
flutter test test/features/mind_aid
```

`mindaid:cx:test` synchronizes the reviewed specification and then tests the
real draft agent. It uses new sessions for isolated intent checks and retained
sessions for multi-turn dialogue checks. The required coverage includes:

- ordinary greetings and small talk;
- academic and mood support in English and Taglish;
- no-match clarification;
- assessment and counseling handoff;
- greeting mixed with crisis language;
- a normal dialogue that changes into a crisis disclosure.

Any failure blocks pilot activation.

## Step 4: Deploy only the authoritative callable

```powershell
firebase deploy --only "functions:sendMindAidMessage,functions:sendMindAidMessageDev" --project mind-mates-cd2cf --force
```

After deployment, confirm both Functions are healthy and that their runtime
has `DIALOGFLOW_CX_AGENT_ID` and `DIALOGFLOW_CX_LOCATION`. Do not place a
service-account key in the Flutter app.

## Step 5: Keep production disabled during review

These two independent gates must remain closed until the pilot is approved:

- Firestore `mind_aid_config/rollout`: `enabled=false`, `percentage=0`, and no
  unapproved pilot UIDs.
- Remote Config `mind_aid_dialogflow_enabled=false` for production users.

The server gate is authoritative. Enabling only Remote Config must not grant
cloud access to a user who is outside the server rollout.

## Step 6: Activate a controlled pilot

Only after the content and red-team review is signed off:

1. Add specific tester Firebase UIDs to `pilotUserIds`; keep percentage at 0.
2. Enable `mind_aid_dialogflow_enabled` for the tester app/condition only.
3. Verify greeting, support, fallback, action, offline fallback, and crisis
   journeys on a newly built Flutter app.
4. Review aggregate metrics: intent, source, fallback count, safety level,
   latency, and error rate. Do not export or inspect raw student transcripts.
5. Fix and re-test every unsafe response, false crisis escalation, broken
   action, or high-frequency no-match before expanding the pilot.
6. Increase server percentage only after formal approval, using small staged
   increments with a documented rollback owner.

## Rollback

Set Firestore rollout `enabled=false` and `percentage=0`, remove pilot UIDs if
needed, and set Remote Config `mind_aid_dialogflow_enabled=false`. The app then
uses its local conversation engine. Rollback does not require deleting the CX
agent or its test history.

## Verification record: 2026-08-11

- Draft agent synchronized with six custom flows and 17 custom intents.
- 16 isolated CX cases passed.
- Seven turns across three retained-session dialogues passed.
- Eight Functions specification/safety tests passed.
- 45 Flutter MindAid tests passed and scoped analysis reported no issues.
- Production rollout and Remote Config remained disabled.
