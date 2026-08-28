# Support-contact safety audit

No repository evidence was found confirming a phone number, email address, office location, office hours, hotline availability, approving authority, or verification date for a production support contact.

| Previous value or claim | Previous location | Intended purpose | Verification evidence | Action |
|---|---|---|---|---|
| `+63 912 345 6789` | Assessment completion support card; counseling screen | Counseling/urgent support | None found; recognizable placeholder pattern | Removed from active UI |
| `pacc@ucu.edu.ph` | Assessment completion support card; counseling screen | Counseling contact | None found | Removed from active UI |
| “PACC Crisis Hotline available 24/7” | Counseling screen | Crisis contact and availability | None found | Removed; safe fallback shown |
| “PAACC counseling services are available 24/7” | Insights screen | Counseling availability | None found | Removed |
| “PACC Office, 2nd Floor, Main Building” | Generated appointment location | Appointment location | None found | Replaced with confirmation-required text |
| Legacy `paccPhone`, `campusSecurityPhone`, and `emergencyPhone` fields | `mind_aid_config/support_contacts` | Server safety response | Values had no required authority/date/status metadata | Deprecated and suppressed |

The replacement schema requires `value`, `type`, `displayName`, `availability`, `verificationStatus`, `verifiedAt`, `approvingAuthority`, and `enabled`. Only enabled, explicitly verified entries with a valid verification date and named authority are shown by the server safety response. Missing or invalid configuration produces a warning log and neutral local-verification guidance.

Mobile assessment and counseling cards remain on the safe fallback until a reviewed repository/provider is approved for distributing verified contacts to those screens.
