# Spec: todo-reminder-app - Requirements

Short description
- A lightweight, user-friendly Flutter todo & reminder app that lets users create tasks, set one-off or recurring reminders, and receive local notifications. Focus on offline-first reliability, privacy, and accessible UI for mobile (iOS & Android).

Goals (high level)
- Let users create, edit, and delete todo tasks with title, notes, due date/time, and optional recurrence.
- When a reminder/todo times out, the app should repeatedly read out the reminder/todo every 20 seconds until the user stops it.
 - Allow voice input for creating a todo or reminder (speech-to-text), including quick natural commands like "Remind me to buy milk tomorrow at 9am"; prefer on-device speech recognition for privacy where available.
- Provide a simple, accessible UI with clear task states (pending, completed, snoozed).
- Persist data locally and optionally export/import as JSON.

Primary personas
- Casual user: wants quick, low-friction task creation and reminders.
- Power user: wants recurring reminders, snooze, and basic filtering (today, upcoming, completed).

User stories & acceptance criteria

1) As a user, I can create a task with a title so I can remember something I must do.
  - Acceptance: New task appears in the list with title; createdAt timestamp saved.

2) As a user, I can add an optional due date/time and set a reminder so I get notified.
  - Acceptance: Local notification is scheduled for the specified date/time and fires on time.

3) As a user, I can choose recurrence (daily, weekly, monthly) for a task.
  - Acceptance: Recurring reminders re-schedule themselves after firing according to rule.

4) As a user, I can snooze a reminder for a configurable period.
  - Acceptance: Snooze creates a new one-off reminder for the snooze duration.

5) As a user, I can mark a task as completed or delete it.
  - Acceptance: Completed tasks can be filtered out and have completedAt timestamp.

6) As a user, I can view tasks filtered by Today, Upcoming, and Completed.
  - Acceptance: Filters return correct sets based on due date and completed status.

7) As a user, my tasks persist across app restarts and device reboots.
  - Acceptance: Data stored locally; notifications persist after device reboot (where platform supports it).

8) As a user, I can create a todo or reminder using voice input so I can add items hands-free.
  - Acceptance: User taps a microphone button, speaks a command (e.g. "Remind me to buy milk tomorrow at 9am"), the app offers a parsed task preview with title and due date/time populated; user can confirm to save. Speech-to-text should work on-device where platform supports it, and privacy settings expose whether speech data is processed locally or sent to platform/cloud services.

Home screen (detailed requirements)
- Purpose: The Home screen is the primary place where users see today's schedule and quickly access tasks for nearby days.
- Layout and behavior:
  - Top date strip:
    - Shows a horizontal sequence of days with the selected date centered by default.
    - When the app opens, the selected date is `today` and displayed in the center.
    - The two previous days (today-2, today-1) are shown to the left, and the two next days (today+1, today+2) to the right.
    - Each day cell shows: weekday label (e.g., Tue), numeric day (e.g., 4), and a small dot/badge if there are tasks on that date.
    - The user can scroll the date strip left or right to reveal older/newer dates; the strip should allow fling and smooth scrolling.
    - Tapping any date cell selects that date and updates the main task list below.

  - Main section — tasks for the selected date:
    - Lists all tasks and events for the currently selected date in chronological order.
    - Each row displays:
      - Title (primary text).
      - Remaining time (secondary text) shown as a concise human-friendly delta (e.g., "in 2h 15m", "due now", "3d"), updated live while the screen is visible.
      - Small icon or pill for recurrence status if the task is recurring.
    - Row interactions:
      - Swipe left (drag left) on a row reveals a prominent 'Delete' button. Tapping Delete shows a confirmation (optional lightweight undo via SnackBar) and deletes the item.
      - Tap on a row opens the Task Detail screen for that item.
      - Long-press could show a quick actions menu (e.g., Mark Done, Snooze, Edit) — optional enhancement.

  - Empty state:
    - If there are no tasks for the selected date, show a friendly empty state with a prominent CTA to create a new task (microphone quick-add + create button).

  - Performance & accessibility:
    - Scrolling the date strip and task list should be smooth (60fps target on target devices).
    - All interactive elements must be reachable by TalkBack/VoiceOver and have proper accessibility labels.

Acceptance criteria (Home screen)
- On cold start, the app shows today centered in the top date strip and lists today's tasks sorted by time.
- Swiping left on a row reveals Delete and tapping it deletes the task (and offers undo via SnackBar).
- Tapping a row opens the Task Detail screen for that item.
- Scrolling the date strip updates the selected date and the task list fairly immediately (no heavy blocking work).

Non-functional requirements
- Offline-first: app works without network.
- Privacy: no user data is sent to servers by default.
- Cross-platform: single Flutter codebase for iOS and Android.
- Performance: start-up < 500ms on mid-range devices; scheduling operations fast.
- Accessibility: support large fonts and screen readers.

Constraints & assumptions
- No cloud sync in initial scope (optional future task).
- Use local persistence (SQLite / Hive) depending on design trade-offs.
- Use Flutter stable (current LTS) and null-safety.
- Use platform notification APIs via well-maintained packages.

Risks
- Platform differences: Android background restrictions and iOS notification limits.
- Recurrence edge-cases (DST, timezone changes).

Success metrics
- Users can create and receive a scheduled notification in the same session.
- >95% notifications fire on time across test devices (excluding network or OS limitations).

Deliverables for Requirements phase
- `.spec-workflow/specs/todo-reminder-app/requirements.md` (this file)
