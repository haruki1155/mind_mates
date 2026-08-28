# MindAid Dialogflow CX Setup

The repeatable synchronization, validation, deployment, and pilot procedure is
documented in [mind_aid_cx_operations.md](mind_aid_cx_operations.md).

The Flutter app never calls Dialogflow directly. It calls the authenticated
`sendMindAidMessage` Firebase callable in `asia-southeast1`; the Function uses
its Google service identity to call CX.

## 1. Enable services and create the agent

1. Upgrade the Firebase project to Blaze if it is not already using billing.
2. In the Google Cloud project linked to Firebase, enable:
   - Dialogflow API
   - Cloud Functions API
   - Cloud Build API
   - Artifact Registry API
   - Firebase Remote Config
3. Open Conversational Agents / Dialogflow CX and create an agent:
   - Display name: `MindAid`
   - Location: `asia-southeast1 (Singapore)`
   - Default language: English
   - Time zone: `Asia/Manila`
4. Copy the agent ID from the agent resource name. The location cannot be
   changed after creation without exporting and restoring the agent.

Create `functions/.env.<firebase-project-id>` locally:

```dotenv
DIALOGFLOW_CX_AGENT_ID=00000000-0000-0000-0000-000000000000
DIALOGFLOW_CX_LOCATION=asia-southeast1
```

Do not add a service-account JSON key to Flutter or to source control.

## 2. IAM

Find the runtime service account used by the 2nd-generation Function and grant
it `roles/dialogflow.client`. A project owner can run:

```powershell
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID `
  --member="serviceAccount:YOUR_FUNCTION_SERVICE_ACCOUNT" `
  --role="roles/dialogflow.client"
```

Firebase Authentication and App Check should remain enabled for the callable.
The Function also validates authentication, consent, rollout, message length,
request IDs, rate limits, and duplicate requests.

## 3. Agent design

Create these flows and route high-risk intents before any no-match generator:

| Flow | Example intents | Response policy |
| --- | --- | --- |
| Welcome | greeting, capabilities, goodbye | Deterministic |
| General Support | overwhelmed, lonely, motivation | Deterministic approved responses |
| Academic Stress | exams, workload, deadlines, burnout | Deterministic approved responses |
| Mood and Coping | anxiety, low mood, sleep, grounding | Deterministic intents; approved coping steps |
| Assessment | explain result, concern category | Deterministic; screening is not diagnosis |
| Counseling Handoff | talk to PACC, book counselor | Deterministic action payload |
| Crisis Safety | self-harm, suicide, violence, unsafe now | Deterministic; never enable a generator |

Use the existing records under `assets/data/mind_aid/` as the approved source
for intents and response wording. Add English and common Taglish training
phrases to the same English intents. Do not upload private notes, mood notes, raw
assessment answers, user contact details, or production transcripts as
training data.

The current reviewed configuration does not use a generator or webhook in any
flow. Its no-match handlers ask a deterministic clarification question. Do not
enable generative fallback without a separate clinical, privacy, security, and
red-team review.

## 4. Custom payload contract

CX fulfillment can return plain text plus this optional custom payload. The app
ignores action types outside its compiled allowlist.

```json
{
  "suggestions": ["Try a breathing exercise", "Help me contact PACC"],
  "actions": [
    {"type": "startBreathing", "label": "Start breathing exercise"},
    {
      "type": "bookAppointment",
      "label": "Book an appointment",
      "payload": {"concern": "I would like support with academic stress."}
    }
  ]
}
```

Allowed types are `logMood`, `startBreathing`, `openAssessment`,
`openInsights`, `openCounselingServices`, `bookAppointment`, and
`viewAppointments`. CX must never return Flutter route names.

The Function supplies only derived session parameters: mood trend, recent mood
average, latest mood level, assessment level/score, up to three concern
categories, streak, last check-in time, launch context, and verified support
contacts.

## 5. Firestore and Remote Config

Create `mind_aid_config/rollout` in the Firebase console:

```json
{
  "enabled": false,
  "percentage": 0,
  "pilotUserIds": ["FIREBASE_UID_FOR_TESTER"]
}
```

Create `mind_aid_config/support_contacts` only after the school has verified
the values:

```json
{
  "contacts": [{
    "value": "INSTITUTIONALLY_VERIFIED_VALUE",
    "type": "counseling",
    "displayName": "APPROVED_DISPLAY_NAME",
    "availability": "APPROVED_AVAILABILITY_TEXT",
    "verificationStatus": "verified",
    "verifiedAt": "2026-01-01T00:00:00Z",
    "approvingAuthority": "NAMED_INSTITUTIONAL_AUTHORITY",
    "enabled": true
  }]
}
```

The Functions suppress entries missing any verification field. Do not enter
placeholder values or availability claims. Replace the example verification
date only with the actual approval date.

Create the Remote Config Boolean `mind_aid_dialogflow_enabled`. Set it to
`true` for the pilot app build; the callable still enforces the server-side UID
allowlist. The app defaults to `false` and uses the local engine if Remote
Config cannot be fetched.

For local tester builds only, Remote Config can be bypassed with:

```powershell
flutter run --dart-define=MINDAID_DIALOGFLOW_FORCE=true
```

This flag does not bypass server consent or rollout enforcement.

## 6. Test and deploy

Synchronize the reviewed agent specification before deploying Functions:

```powershell
cd functions
npm run mindaid:cx:dry-run
npm run mindaid:cx:apply
npm run mindaid:cx:test
```

```powershell
cd functions
npm install
npm test
cd ..

flutter analyze
flutter test test/features/mind_aid

firebase emulators:exec --only firestore,functions "npm --prefix functions test"
firebase deploy --only firestore:rules,firestore:indexes,functions
```

In the CX simulator, test ordinary English and Taglish messages, ambiguous
messages, prompt injection, unsupported diagnoses, medication requests,
academic stress, appointment handoff, and all crisis phrases in the reviewed
red-team list. Confirm crisis routes never invoke generative fallback.

Start with pilot UIDs. Review only aggregate MindAid quality metrics in the
admin dashboard: turns, intents, source, fallback count, safety level, and
latency. Do not inspect or export raw student transcripts.
