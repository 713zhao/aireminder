# Spec: todo-reminder-app - Design

Overview
- Single Flutter app targeting iOS & Android. Core modules: UI, Persistence, Scheduling & Notifications, Background handling, Settings.

Architecture
- Presentation: Flutter widgets (Riverpod or Provider for state management).
- Data: Local storage layer (Repository pattern) using Hive for lightweight schema or SQLite via sqflite for relational queries.
- Notifications: Platform notifications via flutter_local_notifications for scheduling and handling; consider android_alarm_manager_plus for background execution on Android if needed.
- Background: Use platform-specific boot-receivers (Android) and notification-delivery mechanisms; keep logic minimal in background.

Packages (recommendations)
- flutter_local_notifications — scheduling and showing local notifications.
- timezone — for timezone-aware scheduling.
- hive (or sembast) — lightweight local datastore (or sqflite if relational queries required).
- riverpod — state management (or provider/get_it based on team familiarity).

Data model
- Task
  - id: string (UUID)
  - title: string
  - notes: string?
  - createdAt: DateTime
  - dueAt: DateTime?
  - recurrenceRule: string? (iCal RRULE or simplified enum)
  - isCompleted: bool
  - completedAt: DateTime?
  - reminderId: int? (platform notification id)

Key design decisions
- Persistence choice: Hive for speed and zero-copy simplicity; choose sqflite if the team needs complex querying.
- Recurrence representation: start with simplified recurrence (none, daily, weekly, monthly) with RFC5545/rrule left as future enhancement.
- Notifications: Use flutter_local_notifications with timezone plugin for robust scheduling across DST.

Flows

Create task
- UI: form to enter title, notes, due date/time, recurrence
- Backend: create Task, persist, schedule notification if dueAt present

Voice input (design)
- Flow: User taps a microphone icon in the Home or Create Task screen → app starts speech recognition → speech is converted to text → lightweight parsing extracts title, date/time, and optional recurrence → the app shows a preview form populated with parsed fields → user confirms to save.
- STT options: prefer on-device speech recognition (Speech to Text plugin or platform APIs) for privacy. Provide a fallback to platform cloud-based recognition only with explicit user consent.
- Parsing: use simple rule-based parsing for the MVP (keywords like "tomorrow", "at", weekdays, numeric times). Consider a small library (chrono or custom parser port) rather than heavy NLP models. Keep parser deterministic and testable.
- Error handling: if parsing fails, show the full transcribed text in the create form and allow manual editing.
- Data & privacy: clearly expose in Settings whether voice data is processed locally or sent to the platform/service. Do not send audio off-device by default.

Notification fired
- Action: Show notification; tapping opens the app to task detail; action buttons: Mark Done, Snooze, Stop Readout
- Text-to-Speech repeat behaviour: when a reminder fires, the app should read the reminder aloud and then repeat the readout every 20 seconds until the user explicitly stops it (via a Stop Readout action, Mark Done, or in-app control).
- Implementation notes:
  - Prefer using a TTS engine (e.g., flutter_tts) for spoken readout. Manage audio focus so the readout respects other audio (music/phone calls).
  - Provide a visible and actionable notification button 'Stop Readout' and a lock-screen action where platform permits so the user can immediately stop repeated sounds without unlocking the device.
  - Maintain a local repeat controller that tracks active repeating readouts (task id, start time, repeat interval, next scheduled attempt). The controller should be cancellable and persisted briefly so that reboots or process restarts can restore state where platform permits.
  - Provide a sensible cap (configurable in Settings) on how long repeats run (for example, default 5 minutes or N repeats) to avoid battery drain and user annoyance; make this configurable and document it in Settings.
  - Respect device Do Not Disturb (DND) and system sound/vibration settings. If DND blocks audible alerts, provide a fallback visual notification and do not force audible TTS unless user explicitly opts-in in Settings.

Platform-specific considerations
- Android:
  - Implement the repeating readout using a background mechanism. Best option is a foreground service (via platform channels or packages that support foreground execution) to guarantee execution even when the app is backgrounded or the device is idle. The foreground service should show a persistent notification while repeating readout is active (with Stop/Mark Done actions).
  - As an alternative for lighter-weight behavior, schedule a series of short alarms (AlarmManager) or repeated local notifications that trigger the app to start TTS. However, AlarmManager behavior varies across OEMs; foreground service provides the most reliable behavior.

- iOS:
  - iOS strictly limits background execution. Long-running background audio for the sole purpose of periodic TTS is problematic and may require enabling Background Modes (audio), which has user-experience and App Store review implications.
  - Pragmatic approach for iOS MVP:
    1. When the app is foregrounded, run repeating TTS normally.
    2. When backgrounded or terminated, schedule repeated local notifications (one per 20s interval up to the configured cap). Local notifications can use a custom sound but cannot run TTS while the app is terminated. When the user taps the notification, open the app and resume TTS if still active.
    3. Consider documenting limitations to users and provide a settings toggle to allow enabling background audio mode (advanced), with clear privacy/UX notes.

Background & reboot handling
- Android: register BootReceiver to reschedule pending notifications after device reboot. For active repeating readouts across reboot, the foreground service approach allows quicker restoration; otherwise, reconstruct repeat controller state on boot and resume if appropriate.
- iOS: scheduled local notifications survive reboot; TTS-only behavior while terminated is not available without special background audio handling.

Background & reboot handling
- Android: register BootReceiver to reschedule pending notifications after device reboot
- iOS: scheduled local notifications survive reboot; ensure plugin setup follows platform docs

Testing
- Unit tests for repository and recurrence logic
- Integration tests for scheduling (mock timezone and notification plugin)
- Manual device tests on Android & iOS for background and reboot behaviors
- Additional testing for repeated readout
  - Unit tests for repeat controller logic (start, stop, persistence, cap enforcement)
  - Integration/manual tests on Android to verify foreground service keeps TTS running and Stop Readout action works when app is backgrounded or device is locked.
  - Manual verification on iOS showing the documented fallback behavior (repeated notifications up to cap) and that tapping notification opens the app and resumes TTS when applicable.

Security & Privacy
- No external network calls by default. If export/import implemented, ensure user-initiated and data stays local.

Open questions
- Should we support advanced recurrence (RRULE) in scope? (Recommend deferred)
- Which persistence library does the team prefer (Hive vs sqflite)?

Deliverables for Design phase
- `.spec-workflow/specs/todo-reminder-app/design.md` (this file)
