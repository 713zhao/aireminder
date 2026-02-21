/**
 * Reminders service - Business logic for querying and filtering reminders
 */

import { getFirestore } from './firebase-config.js';
import {
  sortByDueDate,
  sortByPriority,
  filterByStatus,
  searchReminders,
  formatReminderForLLM,
  daysUntil,
  isToday,
  isPast,
  isOverdue,
  getStatus,
} from './utils.js';

/**
 * Get all reminders for a user
 * @param {string} userId - User email or ID
 * @param {Object} options - Query options
 * @returns {Promise<Array>}
 */
export async function getAllReminders(userId, options = {}) {
  const {
    status = 'all',
    limit = null,
    formatForLLM = true,
  } = options;

  try {
    const db = getFirestore();
    let query = db.collection('reminders').where('ownerId', '==', userId);

    // Filter by completion status
    if (status === 'completed') {
      query = query.where('isCompleted', '==', true);
    } else if (status === 'pending') {
      query = query.where('isCompleted', '==', false);
    }

    const snapshot = await query.get();
    let reminders = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Apply limit if specified
    if (limit) {
      reminders = reminders.slice(0, limit);
    }

    // Format for LLM consumption if requested
    if (formatForLLM) {
      reminders = reminders.map(formatReminderForLLM);
    }

    return reminders;
  } catch (error) {
    console.error('Error fetching reminders:', error);
    throw error;
  }
}

/**
 * Get upcoming reminders for the next N days
 * @param {string} userId - User email or ID
 * @param {number} days - Number of days to look ahead (default: 7)
 * @param {Object} options - Query options
 * @returns {Promise<Array>}
 */
export async function getUpcomingReminders(userId, days = 7, options = {}) {
  const {
    sortBy = 'dueDate',
    includeCompleted = false,
    formatForLLM = true,
  } = options;

  try {
    const db = getFirestore();
    const now = new Date();
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + days);

    let query = db.collection('reminders')
      .where('ownerId', '==', userId)
      .where('dueAt', '>=', now)
      .where('dueAt', '<=', futureDate);

    if (!includeCompleted) {
      query = query.where('isCompleted', '==', false);
    }

    const snapshot = await query.get();
    let reminders = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Sort results
    if (sortBy === 'dueDate') {
      reminders = sortByDueDate(reminders, 'asc');
    } else if (sortBy === 'priority') {
      reminders = sortByPriority(reminders);
    }

    // Format for LLM consumption if requested
    if (formatForLLM) {
      reminders = reminders.map(formatReminderForLLM);
    }

    return reminders;
  } catch (error) {
    console.error('Error fetching upcoming reminders:', error);
    throw error;
  }
}

/**
 * Get reminders due today
 * @param {string} userId - User email or ID
 * @param {Object} options - Query options
 * @returns {Promise<Array>}
 */
export async function getTodayReminders(userId, options = {}) {
  const {
    includeCompleted = false,
    formatForLLM = true,
  } = options;

  try {
    const db = getFirestore();
    const reminders = await getAllReminders(userId, {
      status: includeCompleted ? 'all' : 'pending',
      formatForLLM: false,
    });

    const todayReminders = reminders.filter(r =>
      r.dueAt && isToday(new Date(r.dueAt))
    );

    // Format for LLM consumption if requested
    if (formatForLLM) {
      return todayReminders.map(formatReminderForLLM);
    }

    return todayReminders;
  } catch (error) {
    console.error('Error fetching today reminders:', error);
    throw error;
  }
}

/**
 * Get overdue reminders
 * @param {string} userId - User email or ID
 * @param {Object} options - Query options
 * @returns {Promise<Array>}
 */
export async function getOverdueReminders(userId, options = {}) {
  const {
    formatForLLM = true,
  } = options;

  try {
    const reminders = await getAllReminders(userId, {
      status: 'pending',
      formatForLLM: false,
    });

    const overdueReminders = reminders.filter(r =>
      r.dueAt && isPast(new Date(r.dueAt))
    );

    // Format for LLM consumption if requested
    if (formatForLLM) {
      return overdueReminders.map(formatReminderForLLM);
    }

    return overdueReminders;
  } catch (error) {
    console.error('Error fetching overdue reminders:', error);
    throw error;
  }
}

/**
 * Get a specific reminder by ID
 * @param {string} reminderId - Reminder ID
 * @param {string} userId - User email or ID (for validation)
 * @param {Object} options - Query options
 * @returns {Promise<Object>}
 */
export async function getReminderById(reminderId, userId, options = {}) {
  const { formatForLLM = true } = options;

  try {
    const db = getFirestore();
    const doc = await db.collection('reminders').doc(reminderId).get();

    if (!doc.exists) {
      throw new Error('Reminder not found');
    }

    const reminder = {
      id: doc.id,
      ...doc.data(),
    };

    // Verify ownership
    if (reminder.ownerId !== userId && 
        (!reminder.sharedWith || !reminder.sharedWith.includes(userId))) {
      throw new Error('Access denied');
    }

    if (formatForLLM) {
      return formatReminderForLLM(reminder);
    }

    return reminder;
  } catch (error) {
    console.error('Error fetching reminder:', error);
    throw error;
  }
}

/**
 * Search reminders
 * @param {string} userId - User email or ID
 * @param {string} query - Search query
 * @param {Object} options - Query options
 * @returns {Promise<Array>}
 */
export async function searchUserReminders(userId, query, options = {}) {
  const {
    status = 'all',
    limit = null,
    formatForLLM = true,
  } = options;

  try {
    let reminders = await getAllReminders(userId, {
      status,
      formatForLLM: false,
    });

    reminders = searchReminders(reminders, query);

    if (limit) {
      reminders = reminders.slice(0, limit);
    }

    if (formatForLLM) {
      return reminders.map(formatReminderForLLM);
    }

    return reminders;
  } catch (error) {
    console.error('Error searching reminders:', error);
    throw error;
  }
}

/**
 * Get reminders summary for a user
 * @param {string} userId - User email or ID
 * @returns {Promise<Object>}
 */
export async function getRemindersSummary(userId) {
  try {
    const reminders = await getAllReminders(userId, {
      status: 'all',
      formatForLLM: false,
    });

    const completed = reminders.filter(r => r.isCompleted);
    const pending = reminders.filter(r => !r.isCompleted);
    const overdue = pending.filter(r => r.dueAt && isPast(new Date(r.dueAt)));
    const dueToday = reminders.filter(r =>
      r.dueAt && isToday(new Date(r.dueAt)) && !r.isCompleted
    );
    const upcoming = pending.filter(r =>
      r.dueAt && !isPast(new Date(r.dueAt))
    );

    return {
      total: reminders.length,
      completed: completed.length,
      pending: pending.length,
      overdue: overdue.length,
      dueToday: dueToday.length,
      upcoming: upcoming.length,
      completionRate: reminders.length > 0 
        ? ((completed.length / reminders.length) * 100).toFixed(1)
        : 0,
    };
  } catch (error) {
    console.error('Error generating summary:', error);
    throw error;
  }
}

/**
 * Get shared reminders for a user
 * @param {string} userId - User email or ID
 * @param {Object} options - Query options
 * @returns {Promise<Array>}
 */
export async function getSharedReminders(userId, options = {}) {
  const {
    formatForLLM = true,
  } = options;

  try {
    const db = getFirestore();
    const snapshot = await db.collection('reminders')
      .where('sharedWith', 'array-contains', userId)
      .get();

    let reminders = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    if (formatForLLM) {
      return reminders.map(formatReminderForLLM);
    }

    return reminders;
  } catch (error) {
    console.error('Error fetching shared reminders:', error);
    throw error;
  }
}

/**
 * Create a new reminder
 * @param {string} userId - User email or ID (owner)
 * @param {string} title - Reminder title
 * @param {Object} options - Reminder options
 * @returns {Promise<Object>}
 */
export async function createReminder(userId, title, options = {}) {
  const {
    notes = null,
    dueAt = null,
    recurrence = null,
    remindBeforeMinutes = 10,
    recurrenceEndDate = null,
    weeklyDays = null,
    sharedWith = null,
    formatForLLM = true,
  } = options;

  try {
    if (!title || title.trim().length === 0) {
      throw new Error('Title is required');
    }

    const db = getFirestore();
    const now = new Date();

    const reminderData = {
      title: title.trim(),
      notes: notes ? notes.trim() : null,
      createdAt: now,
      updatedAt: now,
      ownerId: userId,
      isCompleted: false,
      completedAt: null,
      isDisabled: false,
      disabledUntil: null,
      remindBeforeMinutes,
      dueAt: dueAt ? new Date(dueAt) : null,
      recurrence: recurrence || null,
      recurrenceEndDate: recurrenceEndDate ? new Date(recurrenceEndDate) : null,
      weeklyDays: weeklyDays || null,
      isShared: sharedWith && sharedWith.length > 0,
      sharedWith: sharedWith || [],
      lastModifiedBy: userId,
      deleted: false,
      version: 1,
    };

    const docRef = await db.collection('reminders').add(reminderData);

    const reminder = {
      id: docRef.id,
      ...reminderData,
    };

    if (formatForLLM) {
      return formatReminderForLLM(reminder);
    }

    return reminder;
  } catch (error) {
    console.error('Error creating reminder:', error);
    throw error;
  }
}

/**
 * Update an existing reminder
 * @param {string} reminderId - Reminder ID
 * @param {string} userId - User email or ID (must be owner)
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>}
 */
export async function updateReminder(reminderId, userId, updates = {}) {
  const { formatForLLM = true } = updates;
  const updateFields = { ...updates };
  delete updateFields.formatForLLM;

  try {
    const db = getFirestore();
    const reminderRef = db.collection('reminders').doc(reminderId);
    const doc = await reminderRef.get();

    if (!doc.exists) {
      throw new Error('Reminder not found');
    }

    const reminder = doc.data();

    // Verify ownership
    if (reminder.ownerId !== userId) {
      throw new Error('Access denied: You can only edit your own reminders');
    }

    // Validate title if being updated
    if (updateFields.title !== undefined && 
        (!updateFields.title || updateFields.title.trim().length === 0)) {
      throw new Error('Title cannot be empty');
    }

    // Prepare update data
    const dataToUpdate = {
      ...updateFields,
      updatedAt: new Date(),
      lastModifiedBy: userId,
      version: (reminder.version || 0) + 1,
    };

    // Convert dates if provided
    if (updateFields.dueAt !== undefined) {
      dataToUpdate.dueAt = updateFields.dueAt ? new Date(updateFields.dueAt) : null;
    }
    if (updateFields.recurrenceEndDate !== undefined) {
      dataToUpdate.recurrenceEndDate = updateFields.recurrenceEndDate 
        ? new Date(updateFields.recurrenceEndDate) 
        : null;
    }

    // Update shared status based on sharedWith array
    if (updateFields.sharedWith !== undefined) {
      dataToUpdate.isShared = updateFields.sharedWith && updateFields.sharedWith.length > 0;
    }

    await reminderRef.update(dataToUpdate);

    const updatedReminder = {
      id: reminderId,
      ...reminder,
      ...dataToUpdate,
    };

    if (formatForLLM) {
      return formatReminderForLLM(updatedReminder);
    }

    return updatedReminder;
  } catch (error) {
    console.error('Error updating reminder:', error);
    throw error;
  }
}

/**
 * Delete a reminder
 * @param {string} reminderId - Reminder ID
 * @param {string} userId - User email or ID (must be owner)
 * @returns {Promise<Object>}
 */
export async function deleteReminder(reminderId, userId) {
  try {
    const db = getFirestore();
    const reminderRef = db.collection('reminders').doc(reminderId);
    const doc = await reminderRef.get();

    if (!doc.exists) {
      throw new Error('Reminder not found');
    }

    const reminder = doc.data();

    // Verify ownership
    if (reminder.ownerId !== userId) {
      throw new Error('Access denied: You can only delete your own reminders');
    }

    // Soft delete - mark as deleted instead of removing
    await reminderRef.update({
      deleted: true,
      deletedAt: new Date(),
      lastModifiedBy: userId,
      version: (reminder.version || 0) + 1,
    });

    return {
      success: true,
      message: `Reminder "${reminder.title}" deleted successfully`,
      reminderId,
    };
  } catch (error) {
    console.error('Error deleting reminder:', error);
    throw error;
  }
}

/**
 * Mark a reminder as completed
 * @param {string} reminderId - Reminder ID
 * @param {string} userId - User email or ID (must be owner or has access)
 * @returns {Promise<Object>}
 */
export async function completeReminder(reminderId, userId) {
  try {
    const db = getFirestore();
    const reminderRef = db.collection('reminders').doc(reminderId);
    const doc = await reminderRef.get();

    if (!doc.exists) {
      throw new Error('Reminder not found');
    }

    const reminder = doc.data();

    // Verify access (owner or shared with user)
    if (reminder.ownerId !== userId && 
        (!reminder.sharedWith || !reminder.sharedWith.includes(userId))) {
      throw new Error('Access denied: You do not have permission to complete this reminder');
    }

    const now = new Date();

    await reminderRef.update({
      isCompleted: true,
      completedAt: now,
      lastModifiedBy: userId,
      version: (reminder.version || 0) + 1,
    });

    const completedReminder = {
      id: reminderId,
      ...reminder,
      isCompleted: true,
      completedAt: now,
      lastModifiedBy: userId,
      version: (reminder.version || 0) + 1,
    };

    return formatReminderForLLM(completedReminder);
  } catch (error) {
    console.error('Error completing reminder:', error);
    throw error;
  }
}
