# Worker API integration status

Implemented from the two supplied worker API documents:

- Home and Jobs send current `lat`/`lng` when available. Jobs requests permission;
  refusal or location failure falls back to the API's profile/city location.
- Returning to Home/Jobs refreshes location and feed. Search/filter requests retain
  coordinates. Pagination preserves location, filters and `all=1`.
- Feed metadata drives the caption/location prompt. Search responses without feed
  metadata use the search count. Empty dashboard feeds stay empty.
- Monthly expected salary in registration, profile and application sheets. Legacy
  daily/hourly profile values convert once for display and save as monthly.
- API wage labels display unchanged. Verified employer badges and nullable distance
  propagate through shared cards (including saved jobs), Home and job details.
- Registration uses live reference skills/categories with no fixed craft count.
- OTP resend uses the server cooldown; public legal/support links are reachable at
  login. Configured email, phone and WhatsApp support channels are rendered.
- Optional KYC can be skipped even if the form contains incomplete document fields.

Deployment dependencies observed on 2026-09-30:

- The live public reference endpoint still returned 40 general-trade skills and
  `hourly`, `daily`, `monthly` wage types. The new server release must be deployed
  for the 14 craft categories and new personalized feed behavior.
- The supplied profile schema does not document the existing client's `address`
  field. Backend support for full street-address persistence needs confirmation.
  This release does not claim to add backend fields or migrations.
- The employer-app wage change described in the document belongs to its separate
  repository and is not included in this worker-app implementation.
