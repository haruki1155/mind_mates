# Mood migration dry-run report — 2026-08-15

Mode: dry run only. No Firestore documents were created, updated, deleted, deployed, or migrated.

## Result

| Check | Result |
| --- | ---: |
| Legacy mood documents scanned | 10 |
| Eligible schema-v2 mood documents | 10 |
| Already schema-v2 documents | 0 |
| Quarantined documents | 0 |
| User wellness states assessed for cutover reset | 11 |

## Provenance rule applied

For every legacy mood, the migration derives the authoritative compact Manila
`YYYYMMDD` date from its Firestore `createdAt` timestamp. Any legacy `dateKey`
and date embedded in the document ID are evidence only; each must agree with
the timestamp-derived date. A missing timestamp, conflict, duplicate target,
or ambiguous identity is quarantined rather than migrated.

All 10 scanned legacy moods passed this provenance rule. No legacy client-
controlled date value was accepted merely because it had a valid format.

## Intended apply behavior (not executed)

The eventual Admin-SDK apply would create canonical immutable schema-v2 mood
documents and archive/reset 11 user wellness streak states for the security
cutover. It was deliberately not run in this validation session.

Command used:

```text
cd functions
npm run moods:dry-run
```
