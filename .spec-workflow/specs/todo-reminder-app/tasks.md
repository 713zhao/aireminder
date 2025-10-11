# Spec: todo-reminder-app - Tasks

Status: - [ ] Pending review

Tasks

- [ ] Task 1: Project scaffold
  - Files: Flutter app base (pubspec.yaml, lib/main.dart)
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Flutter developer
    Task: Create a new Flutter project scaffold with null-safety enabled, add recommended packages (flutter_local_notifications, timezone, hive, riverpod). Create `lib/main.dart` with app entry and basic routing.
    Restrictions: Don't add platform-specific native code beyond plugin setup. Keep UI minimal.
    _Leverage: design.md, requirements.md
    _Requirements: Basic app skeleton, cross-platform support
    Success: `flutter run` starts the app and shows a blank Home screen with app title.

- [ ] Task 2: Data layer and models
  - Files: lib/models/task.dart, lib/data/task_repository.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Flutter developer
    Task: Implement Task model and a repository using Hive (or sqflite if preferred). Include create/read/update/delete APIs and a method to list tasks by filter (today/upcoming/completed).
    Restrictions: Keep interfaces async and testable. Do not implement UI.
    _Leverage: design.md
    _Requirements: Persistence, filters, offline
    Success: Unit tests for repository CRUD pass.

- [ ] Task 3: Notifications & scheduling
  - Files: lib/services/notification_service.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Mobile platform engineer
    Task: Integrate flutter_local_notifications and timezone, implement scheduling and cancellation by reminderId. Ensure scheduled notifications survive device reboot on Android.
    Restrictions: Use plugin APIs only; do not implement cloud messaging.
    _Leverage: design.md
    _Requirements: Reliable local notifications, timezone-aware scheduling
    Success: Unit/integration tests (or manual test instructions) demonstrate scheduling and cancellation.

- [ ] Task 4: Task list UI and details
  - Files: lib/screens/home.dart, lib/screens/task_detail.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Flutter UI developer
    Task: Build the Home screen listing tasks with filters (Today, Upcoming, Completed) and a Task Detail screen for viewing/editing a task.
    Restrictions: Use recommended state management (riverpod). Keep designs accessible.
    _Leverage: design.md, models
    _Requirements: Create/Edit/Delete, filters
    Success: Manual smoke test - create a task and view it in list and detail screens.

- [ ] Task 5: Create task form & recurrence/snooze
  - Files: lib/widgets/task_form.dart, lib/services/recurrence.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Flutter developer
    Task: Implement create/edit form supporting title, notes, due date/time, recurrence (none/daily/weekly/monthly) and snooze actions on notifications.
    Restrictions: Keep recurrence simple; advanced RRULE deferred.
    _Leverage: design.md
    _Requirements: UX for scheduling + snooze
    Success: Manual test - schedule task, receive notification, use snooze to reschedule.

- [ ] Task 6: Background handling & reboot
  - Files: android/ (native manifest changes), lib/services/boot_rescheduler.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Mobile platform engineer
    Task: Ensure scheduled notifications are rescheduled after device reboot (Android BootReceiver or plugin-based approach). Document necessary manifest changes.
    Restrictions: Keep iOS behavior documented; avoid unsupported hacks.
    _Leverage: design.md, notification_service
    _Requirements: Notifications persist across reboot
    Success: Manual device test after reboot shows scheduled notifications restored.

- [ ] Task 7: Export/Import JSON & Settings
  - Files: lib/services/export_service.dart, lib/screens/settings.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Flutter developer
    Task: Implement export/import of tasks to JSON and settings screen for snooze duration default and notification preferences.
    Restrictions: Exports stored locally or shared via share sheet; no cloud storage.
    _Leverage: design.md
    _Requirements: Data portability, basic settings
    Success: Export file created; import restores tasks.

  - Files: test/*, .github/workflows/flutter.yml
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: QA/DevOps
    Task: Add unit tests for models and repository; add a basic CI workflow that runs `flutter test` on push.

- [ ] Task 9: Voice input — STT integration
  - Files: lib/services/voice_service.dart, pubspec.yaml (dependencies)
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Mobile developer
    Task: Integrate on-device speech-to-text support using a suitable Flutter plugin (e.g., speech_to_text) and expose a simple API to start/stop listening and return transcribed text. Provide platform fallbacks and permission handling.
    Restrictions: Do not send audio to third-party servers by default. Ensure microphone permission flows are implemented per-platform.
    _Leverage: design.md
    _Requirements: Voice input capability, on-device-first
    Success: Manual test where microphone button records speech and returns a transcription.

- [ ] Task 10: Voice parsing & command extraction
  - Files: lib/services/voice_parser.dart, test/voice_parser_test.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Developer
    Task: Implement a deterministic parser that extracts title, due date/time, and simple recurrence from free-form transcribed text. Support phrases like "tomorrow", "next Monday", "at 9am", "every day". Add unit tests covering common phrases and edge cases.
    Restrictions: No heavy ML models; keep the parser rule-based and testable.
    _Leverage: design.md
    _Requirements: Parsed preview for voice-created tasks
    Success: Unit tests demonstrating correct extraction for sample sentences.

- [ ] Task 11: Voice UI & preview flow
  - Files: lib/widgets/voice_button.dart, lib/screens/voice_preview.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Flutter UI developer
    Task: Add a microphone button to Home and Create Task screens. After transcription and parsing, show a preview screen populated with parsed fields for user confirmation/edit before saving.
    Restrictions: Keep UI accessible and consistent with app theming.
    _Leverage: design.md, voice_service, voice_parser
    _Requirements: Hands-free quick-add workflow with confirmation
    Success: Manual test - speak a command, see populated preview, and confirm to save.

- [ ] Task 12: Settings & privacy controls for voice
  - Files: lib/screens/settings.dart (update), lib/services/privacy_prefs.dart
  - _Prompt:
    Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
    Role: Flutter developer
    Task: Add Settings toggles to control voice processing: 'On-device speech recognition' (preferred), and a consent toggle 'Allow cloud-based speech processing' with explanation. Store preferences locally and respect them in `voice_service`.
    Restrictions: Do not enable cloud processing by default.
    _Leverage: design.md
    _Requirements: User-visible privacy controls
    Success: Manual test toggling settings changes behavior of voice processing.
    Restrictions: Keep CI minimal; don't require devices.
    _Leverage: repository code
    _Requirements: Automated tests, basic CI
    Success: CI pipeline passes tests.

  - [ ] Task 13: Repeat controller for readout
    - Files: lib/services/repeat_controller.dart, test/repeat_controller_test.dart
    - _Prompt:
      Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
      Role: Flutter developer
      Task: Implement a repeat controller that manages repeated TTS readouts for a task. It should support start, stop, pause, resume, configurable interval (default 20s), and a cap (max duration or max repeats). Persist minimal state so that short-term process restarts can potentially restore active repeats.
      Restrictions: Keep logic platform-agnostic; platform-specific execution (foreground service) handled in separate task.
      _Leverage: design.md
      _Requirements: Repeat every 20s until stopped, configurable cap
      Success: Unit tests verify start/stop/interval/cap behavior.

  - [ ] Task 14: Android foreground service for reliable readout
    - Files: android/src/main/... (native service), lib/services/android_foreground_bridge.dart
    - _Prompt:
      Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
      Role: Android engineer
      Task: Implement a minimal Android foreground service (or integrate a package that provides it) to run TTS readouts reliably while the app is backgrounded or device is idle. Expose start/stop APIs to Dart via platform channels or a supporting plugin. Provide persistent notification with Stop/Mark Done actions while running.
      Restrictions: Keep native code minimal and documented; ensure proper permission and foreground notification handling per Android versions.
      _Leverage: design.md, notification_service
      _Requirements: Reliable repeating TTS on Android background
      Success: Manual test on Android demonstrates repeated readout while app is backgrounded and Stop action works.

  - [ ] Task 15: iOS fallback approach for readout when backgrounded
    - Files: lib/services/ios_readout_fallback.dart, README.md (platform limitations doc)
    - _Prompt:
      Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
      Role: iOS engineer
      Task: Implement the documented fallback for iOS: when the app is backgrounded/terminated, schedule repeated local notifications up to the configured cap; when the app is foregrounded, resume TTS readout via repeat controller. Document any Background Modes implications and user-visible limitations in README.md.
      Restrictions: Avoid using background audio mode unless team explicitly opts in after reviewing App Store implications.
      _Leverage: design.md
      _Requirements: iOS-compatible fallback for repeated readout
      Success: Manual test on iOS demonstrates fallback behavior and documentation covers limitations.

  - [ ] Task 16: Repeat readout settings & DND handling
    - Files: lib/screens/settings.dart (update), lib/services/dnd_manager.dart
    - _Prompt:
      Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
      Role: Flutter developer
      Task: Add Settings for repeat cap (e.g., default 5 minutes), allow user to opt-in to allow audible readout during DND, and implement a DND manager that queries system DND status where possible and enforces respect/default behavior.
      Restrictions: Do not override system DND without explicit consent.
      _Leverage: design.md
      _Requirements: Configurable cap, DND respect with opt-in
      Success: Manual test toggling settings changes how repeated readouts behave with system DND.

  - [ ] Task 17: Tests for repeated readout integration
    - Files: test/integration/repeat_integration_test.dart, test/manual_instructions.md
    - _Prompt:
      Implement the task for spec todo-reminder-app, first run spec-workflow-guide to get the workflow guide then implement the task:
      Role: QA
      Task: Add integration tests for the repeat controller and provide manual device test instructions for Android foreground service and iOS fallback (since CI cannot run device-level background tests reliably).
      Restrictions: Keep CI-friendly tests for unit/integration; include manual steps for device verification.
      _Leverage: repeat_controller, android_foreground_bridge, ios_readout_fallback
      _Requirements: Repeat behavior verified and documented
      Success: Unit/integration tests pass in CI; manual instructions validate device behaviors.

Notes
- After creating these tasks, request approval for requirements.md and then proceed through design and tasks approvals per workflow.

Deliverables for Tasks phase
- `.spec-workflow/specs/todo-reminder-app/tasks.md` (this file)
