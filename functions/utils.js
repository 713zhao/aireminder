/**
 * Utility functions for the MCP reminder server
 */

/**
 * Format a date for display
 * @param {Date} date
 * @returns {string}
 */
export function formatDate(date) {
  if (!date) return null;
  if (typeof date === 'string') date = new Date(date);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

/**
 * Format a date and time for display
 * @param {Date} date
 * @returns {string}
 */
export function formatDateTime(date) {
  if (!date) return null;
  if (typeof date === 'string') date = new Date(date);
  return date.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * Calculate days until a date
 * @param {Date} date
 * @returns {number}
 */
export function daysUntil(date) {
  if (!date) return null;
  if (typeof date === 'string') date = new Date(date);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(date);
  target.setHours(0, 0, 0, 0);
  const diff = target - today;
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
}

/**
 * Check if a date is today
 * @param {Date} date
 * @returns {boolean}
 */
export function isToday(date) {
  if (!date) return false;
  if (typeof date === 'string') date = new Date(date);
  const today = new Date();
  return (
    date.getDate() === today.getDate() &&
    date.getMonth() === today.getMonth() &&
    date.getFullYear() === today.getFullYear()
  );
}

/**
 * Check if a date is in the past
 * @param {Date} date
 * @returns {boolean}
 */
export function isPast(date) {
  if (!date) return false;
  if (typeof date === 'string') date = new Date(date);
  return date < new Date();
}

/**
 * Check if a reminder is overdue
 * @param {Object} reminder
 * @returns {boolean}
 */
export function isOverdue(reminder) {
  return (
    reminder.dueAt &&
    !reminder.isCompleted &&
    isPast(reminder.dueAt)
  );
}

/**
 * Get a human-readable status for a reminder
 * @param {Object} reminder
 * @returns {string}
 */
export function getStatus(reminder) {
  if (reminder.isCompleted) {
    return 'completed';
  }
  if (!reminder.dueAt) {
    return 'no-due-date';
  }
  if (isOverdue(reminder)) {
    return 'overdue';
  }
  if (isToday(reminder.dueAt)) {
    return 'due-today';
  }
  const days = daysUntil(reminder.dueAt);
  if (days <= 0) {
    return 'due-today';
  }
  if (days === 1) {
    return 'due-tomorrow';
  }
  if (days <= 7) {
    return 'due-this-week';
  }
  return 'upcoming';
}

/**
 * Validate a reminder object
 * @param {Object} reminder
 * @returns {boolean}
 */
export function isValidReminder(reminder) {
  return (
    reminder &&
    typeof reminder === 'object' &&
    reminder.id &&
    reminder.title &&
    reminder.createdAt
  );
}

/**
 * Format a reminder for LLM consumption
 * @param {Object} reminder
 * @returns {Object}
 */
export function formatReminderForLLM(reminder) {
  return {
    id: reminder.id,
    title: reminder.title,
    notes: reminder.notes || '',
    status: getStatus(reminder),
    dueDate: formatDate(reminder.dueAt),
    dueDateTime: formatDateTime(reminder.dueAt),
    daysUntil: reminder.dueAt ? daysUntil(reminder.dueAt) : null,
    isCompleted: reminder.isCompleted,
    completedAt: reminder.completedAt ? formatDateTime(reminder.completedAt) : null,
    recurrence: reminder.recurrence || 'none',
    isShared: reminder.isShared || false,
    sharedWith: reminder.sharedWith || [],
    createdAt: formatDateTime(reminder.createdAt),
    isDisabled: reminder.isDisabled || false,
  };
}

/**
 * Sort reminders by due date
 * @param {Array} reminders
 * @param {string} order 'asc' or 'desc'
 * @returns {Array}
 */
export function sortByDueDate(reminders, order = 'asc') {
  return reminders.sort((a, b) => {
    const aDate = a.dueAt ? new Date(a.dueAt).getTime() : Infinity;
    const bDate = b.dueAt ? new Date(b.dueAt).getTime() : Infinity;
    return order === 'asc' ? aDate - bDate : bDate - aDate;
  });
}

/**
 * Sort reminders by status priority
 * @param {Array} reminders
 * @returns {Array}
 */
export function sortByPriority(reminders) {
  const priorityMap = {
    'overdue': 0,
    'due-today': 1,
    'due-tomorrow': 2,
    'due-this-week': 3,
    'upcoming': 4,
    'no-due-date': 5,
    'completed': 6,
  };

  return reminders.sort((a, b) => {
    const aPriority = priorityMap[getStatus(a)] || 99;
    const bPriority = priorityMap[getStatus(b)] || 99;
    return aPriority - bPriority;
  });
}

/**
 * Filter reminders by status
 * @param {Array} reminders
 * @param {string} status 'pending', 'completed', or 'all'
 * @returns {Array}
 */
export function filterByStatus(reminders, status = 'all') {
  if (status === 'pending') {
    return reminders.filter(r => !r.isCompleted);
  }
  if (status === 'completed') {
    return reminders.filter(r => r.isCompleted);
  }
  return reminders;
}

/**
 * Search reminders by query
 * @param {Array} reminders
 * @param {string} query
 * @returns {Array}
 */
export function searchReminders(reminders, query) {
  if (!query) return reminders;
  const q = query.toLowerCase();
  return reminders.filter(
    r =>
      r.title.toLowerCase().includes(q) ||
      (r.notes && r.notes.toLowerCase().includes(q))
  );
}

/**
 * Paginate results
 * @param {Array} items
 * @param {number} limit
 * @param {number} offset
 * @returns {Object}
 */
export function paginate(items, limit = 10, offset = 0) {
  return {
    total: items.length,
    limit,
    offset,
    items: items.slice(offset, offset + limit),
  };
}

/**
 * Create an error response
 * @param {string} code
 * @param {string} message
 * @returns {Object}
 */
export function createErrorResponse(code, message) {
  return {
    success: false,
    error: {
      code,
      message,
    },
  };
}

/**
 * Create a success response
 * @param {*} data
 * @returns {Object}
 */
export function createSuccessResponse(data) {
  return {
    success: true,
    data,
  };
}
