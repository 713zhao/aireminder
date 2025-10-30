import 'dart:convert';

class Task {
  Task({
    required this.id,
    required this.title,
    this.notes,
    required this.createdAt,
    this.dueAt,
    this.recurrence,
    this.isCompleted = false,
    this.completedAt,
    this.reminderId,
    this.isDisabled = false,
    this.disabledUntil,
    this.remindBeforeMinutes = 10,
    this.recurrenceEndDate,
    this.weeklyDays,
    this.ownerId,
    this.sharedWith,
    this.isShared = false,
    this.lastModifiedBy,
  });

  final String id;
  final String title;
  final String? notes;
  final DateTime createdAt;
  DateTime? dueAt;
  String? recurrence;
  bool isCompleted;
  DateTime? completedAt;
  int? reminderId;
  bool isDisabled;
  DateTime? disabledUntil;
  // New fields for enhanced reminders
  int remindBeforeMinutes;
  DateTime? recurrenceEndDate;
  List<int>? weeklyDays; // List of weekday numbers (1=Monday, 7=Sunday)
  // Family sharing fields
  String? ownerId; // Email of the task creator
  List<String>? sharedWith; // List of emails that can access this task
  bool isShared = false;
  String? lastModifiedBy; // Email of last person who modified
  // Firestore sync metadata
  String? serverId;
  DateTime? updatedAt;
  bool deleted = false;
  int version = 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'dueAt': dueAt?.toIso8601String(),
        'recurrence': recurrence,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'reminderId': reminderId,
        'isDisabled': isDisabled,
        'disabledUntil': disabledUntil?.toIso8601String(),
        'remindBeforeMinutes': remindBeforeMinutes,
        'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
        'weeklyDays': weeklyDays,
        'ownerId': ownerId,
        'sharedWith': sharedWith,
        'isShared': isShared,
        'lastModifiedBy': lastModifiedBy,
        'serverId': serverId,
        'updatedAt': updatedAt?.toIso8601String(),
        'deleted': deleted,
        'version': version,
      };

  static Task fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        dueAt: j['dueAt'] != null ? DateTime.parse(j['dueAt'] as String) : null,
        recurrence: j['recurrence'] as String?,
        isCompleted: j['isCompleted'] as bool? ?? false,
        completedAt: j['completedAt'] != null ? DateTime.parse(j['completedAt'] as String) : null,
        reminderId: j['reminderId'] as int?,
        isDisabled: j['isDisabled'] as bool? ?? false,
        disabledUntil: j['disabledUntil'] != null ? DateTime.parse(j['disabledUntil'] as String) : null,
        remindBeforeMinutes: j['remindBeforeMinutes'] as int? ?? 10,
        recurrenceEndDate: j['recurrenceEndDate'] != null ? DateTime.parse(j['recurrenceEndDate'] as String) : null,
        weeklyDays: j['weeklyDays'] != null ? List<int>.from(j['weeklyDays'] as List) : null,
        ownerId: j['ownerId'] as String?,
        sharedWith: j['sharedWith'] != null ? List<String>.from(j['sharedWith'] as List) : null,
        isShared: j['isShared'] as bool? ?? false,
        lastModifiedBy: j['lastModifiedBy'] as String?,
  )..serverId = j['serverId'] as String?
    ..updatedAt = j['updatedAt'] != null ? DateTime.parse(j['updatedAt'] as String) : null
    ..deleted = j['deleted'] as bool? ?? false
    ..version = j['version'] as int? ?? 0;

  @override
  String toString() => jsonEncode(toJson());
}
