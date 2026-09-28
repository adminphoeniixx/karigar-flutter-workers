# Meta App Events setup

The app uses the community-maintained `facebook_app_events` Flutter bridge to
Meta's native Android/iOS SDKs. This adds ad measurement, not Facebook Login.

## Required account configuration

- Meta developer app's numeric App ID and Client Token (not App Secret).
- Add Android platform: package `com.superkarigar.workerapp`, activity
  `com.superkarigar.workerapp.MainActivity`. Register the correct debug/release/
  Google Play app-signing key hashes if required by the Meta dashboard setup.
- Add iOS platform: bundle ID `com.superkarigar.workerapp`; supply the App Store
  numeric ID/store URL when published.
- Connect the app/data source to the advertising account in Meta Business tools.
  Access to Events Manager is needed to verify delivery and configure campaign
  conversion events. No account password needs to be placed in the app.
- Review the app's privacy disclosure and store data declarations for Meta event
  sharing before enabling production measurement.

## Configured builds

1. App ID `2316068148934163` and the supplied Client Token are configured in
   `android/app/src/main/res/values/meta.xml` and `ios/Runner/Info.plist`.
2. Explicit app events are enabled by default. Rebuild normally with
   `flutter run`, `flutter build appbundle` or `flutter build ipa`.
3. Automatic event logging and advertising ID collection remain disabled.
4. To disable explicit events for a build, pass
   `--dart-define=META_EVENTS_ENABLED=false`. Native SDK registration can still
   occur; this flag is not a promise of zero native network activity.
5. On a physical device, open Meta Events Manager > the app's Test Events,
   then open the app, complete registration, view/save a job and apply.
   Verify names, successful-action timing and absence of personal parameters.
   Check Android and iOS separately. Install/ad attribution requires an actual
   campaign/store flow; seeing an event alone does not prove attribution.

## Instrumentation

| Trigger | Event | Location |
| --- | --- | --- |
| Configured cold app start | SDK activation | main.dart / MetaEventsService |
| Successful OTP verification | worker_login | AuthService.verifyOtp |
| Registration form finishes successfully | fb_mobile_complete_registration | RegistrationPage._finish |
| Job details successfully shown, once per page instance | fb_mobile_content_view | JobDetailPage._loadDetail |
| Job becomes saved after successful API response | job_saved | WorkerApiService.toggleSaved |
| Job application API succeeds | job_application_submitted | WorkerApiService.apply |
| Get Started tapped | onboarding_continued | OnboardingPage |
| Current search/filter results load successfully | jobs_searched | JobsTab._load |
| Edit Profile saves successfully | worker_profile_updated | EditProfilePage._save |
| Resume upload/replacement succeeds | resume_uploaded | ResumePage._pick |
| Resume removal succeeds | resume_removed | ResumePage._remove |
| Saved job is removed successfully | job_unsaved | WorkerApiService.toggleSaved |
| Application withdrawal succeeds | job_application_withdrawn | WorkerApiService.withdraw |
| Employer chat opened from an application | employer_chat_opened | ApplicationsTab._contact |
| Phone dialer successfully opens | employer_dialer_opened | JobDetailPage._callEmployer |
| Employer review submission succeeds | employer_review_submitted | WorkerApiService.reviewEmployer |

Only job IDs, content type, registration method, search/filter presence flags
and displayed result counts are supplied. Search text and selected filter values
stay on the device for deduplication; they are never passed to Meta. Initial
unfiltered list loads, identical refreshes and superseded requests do not log
search events. A dialer open is not a completed call, and a chat open is not
proof of a sent message. Profile edits are separate from registration events.
Resume events indicate success only; no filename or document contents are sent. No phone,
OTP, PAN, Aadhaar, KYC document, resume, wage, precise location, chat, name,
email or user matching data is supplied. KYC and purchases are not tracked.
Repeated genuine actions may generate events; this is client analytics, not an
exactly-once backend conversion ledger.

## iOS advertising attribution

Advertising ID collection is currently off. If IDFA-based advertising tracking
is wanted, implement the App Tracking Transparency permission flow, add a clear
`NSUserTrackingUsageDescription`, and only enable ID collection after permission
is granted. Do not treat the build flag as user consent. ATT/IDFA and any
SKAdNetwork campaign configuration remain a separate rollout step; basic event
instrumentation here does not claim full iOS ad attribution.

## Verification status

App ID and Client Token are configured; explicit events are enabled.
Live delivery and credential validity still need Events Manager verification.
No Facebook Login button, purchase event or KYC event has been added.

References:
- https://pub.dev/packages/facebook_app_events
- https://developers.facebook.com/docs/app-events/
- https://developer.apple.com/documentation/apptrackingtransparency
