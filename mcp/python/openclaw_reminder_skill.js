/**
 * AI Reminder OpenClaw Skill
 * 
 * This skill enables OpenClaw to manage reminders via the AI Reminder MCP Server.
 * Place this file in: ~/.openclaw/skills/reminder.js
 * 
 * Usage:
 * - User: "Show me today's reminders"
 * - User: "Add a reminder to call Mom at 3 PM tomorrow"
 * - User: "What reminders do I have next week?"
 * - User: "Mark reminder #123 as done"
 */

export const reminderSkill = {
  name: 'reminders',
  displayName: 'AI Reminders',
  description: 'Manage your reminders with natural language',
  version: '1.0.0',
  author: 'AI Reminder Team',
  
  // Configuration - UPDATE THESE for your setup
  config: {
    apiUrl: process.env.REMINDER_API_URL || 'http://localhost:8000',
    defaultUserId: process.env.REMINDER_USER_ID || '0502@hotmail.com',
    timeout: 10000, // 10 seconds
  },

  // Helper function to make API calls
  async apiCall(endpoint, options = {}) {
    const url = `${this.config.apiUrl}${endpoint}`;
    const fetchOptions = {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      timeout: this.config.timeout,
    };

    try {
      const response = await fetch(url, fetchOptions);
      if (!response.ok) {
        throw new Error(`API returned ${response.status}: ${response.statusText}`);
      }
      return await response.json();
    } catch (error) {
      throw new Error(`Reminder API error: ${error.message}`);
    }
  },

  // Tools that OpenClaw can use
  tools: [
    {
      name: 'list_reminders_today',
      description: 'Get all reminders due today',
      parameters: {
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        const userId = args.userId || this.config.defaultUserId;
        console.log(`[Reminder Skill] Fetching today's reminders for ${userId}`);
        
        const result = await this.apiCall(
          `/api/reminders/today?userId=${encodeURIComponent(userId)}`
        );
        
        if (result.success && result.data.length > 0) {
          const reminders = result.data
            .map((r, i) => `${i + 1}. ${r.title} (Due: ${r.dueAt}) ${r.isCompleted ? '✓' : ''}`)
            .join('\n');
          return `You have ${result.data.length} reminders today:\n${reminders}`;
        } else if (result.success) {
          return "You have no reminders due today. Great job!";
        } else {
          return `Error: ${result.error || 'Failed to fetch reminders'}`;
        }
      },
    },

    {
      name: 'list_reminders_upcoming',
      description: 'Get upcoming reminders for the next N days',
      parameters: {
        days: {
          type: 'number',
          description: 'Number of days to look ahead (default: 7)',
          optional: true,
        },
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        const userId = args.userId || this.config.defaultUserId;
        const days = args.days || 7;
        console.log(`[Reminder Skill] Fetching upcoming reminders for ${days} days`);
        
        const result = await this.apiCall(
          `/api/reminders/upcoming?days=${days}&userId=${encodeURIComponent(userId)}`
        );
        
        if (result.success && result.data.length > 0) {
          const reminders = result.data
            .map((r, i) => `${i + 1}. ${r.title} (Due: ${r.dueAt})`)
            .join('\n');
          return `Upcoming reminders (${result.data.length} total):\n${reminders}`;
        } else {
          return `No upcoming reminders in the next ${days} days.`;
        }
      },
    },

    {
      name: 'get_reminders_summary',
      description: 'Get a summary of all your reminders',
      parameters: {
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        const userId = args.userId || this.config.defaultUserId;
        console.log(`[Reminder Skill] Fetching reminder summary`);
        
        const result = await this.apiCall(
          `/api/reminders/summary?userId=${encodeURIComponent(userId)}`
        );
        
        if (result.success) {
          const data = result.data;
          return `📊 Reminder Summary:\n` +
            `Total: ${data.total}\n` +
            `Pending: ${data.pending}\n` +
            `Completed: ${data.completed}\n` +
            `Overdue: ${data.overdue}\n` +
            `This Week: ${data.thisWeek}`;
        } else {
          return `Error fetching summary: ${result.error}`;
        }
      },
    },

    {
      name: 'get_overdue_reminders',
      description: 'Get all overdue reminders',
      parameters: {
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        const userId = args.userId || this.config.defaultUserId;
        console.log(`[Reminder Skill] Fetching overdue reminders`);
        
        const result = await this.apiCall(
          `/api/reminders/overdue?userId=${encodeURIComponent(userId)}`
        );
        
        if (result.success && result.data.length > 0) {
          const reminders = result.data
            .map((r, i) => `${i + 1}. ${r.title} (Was due: ${r.dueAt})`)
            .join('\n');
          return `⚠️ You have ${result.data.length} overdue reminders:\n${reminders}`;
        } else {
          return "Great! No overdue reminders.";
        }
      },
    },

    {
      name: 'create_reminder',
      description: 'Create a new reminder',
      parameters: {
        title: {
          type: 'string',
          description: 'Reminder title/description (required)',
        },
        dueAt: {
          type: 'string',
          description: 'Due date/time in ISO 8601 format (e.g., 2026-02-25T15:00:00)',
          optional: true,
        },
        notes: {
          type: 'string',
          description: 'Additional notes',
          optional: true,
        },
        remindBeforeMinutes: {
          type: 'number',
          description: 'Minutes before due date to send reminder (default: 10)',
          optional: true,
        },
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        if (!args.title || !args.title.trim()) {
          return 'Error: Reminder title is required';
        }

        const userId = args.userId || this.config.defaultUserId;
        console.log(`[Reminder Skill] Creating reminder: ${args.title}`);
        
        const payload = {
          title: args.title,
          dueAt: args.dueAt,
          notes: args.notes,
          remindBeforeMinutes: args.remindBeforeMinutes || 10,
          userId: userId,
        };

        const result = await this.apiCall(
          '/api/reminders/create',
          {
            method: 'POST',
            body: JSON.stringify(payload),
          }
        );
        
        if (result.success) {
          return `✅ Reminder created: "${result.data.title}"\nDue: ${result.data.dueAt}`;
        } else {
          return `Error: ${result.error || 'Failed to create reminder'}`;
        }
      },
    },

    {
      name: 'search_reminders',
      description: 'Search reminders by keyword',
      parameters: {
        query: {
          type: 'string',
          description: 'Search query (keyword)',
        },
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        if (!args.query || !args.query.trim()) {
          return 'Error: Search query is required';
        }

        const userId = args.userId || this.config.defaultUserId;
        console.log(`[Reminder Skill] Searching for: ${args.query}`);
        
        const result = await this.apiCall(
          `/api/reminders/search?query=${encodeURIComponent(args.query)}&userId=${encodeURIComponent(userId)}`
        );
        
        if (result.success && result.data.length > 0) {
          const reminders = result.data
            .map((r, i) => `${i + 1}. ${r.title} (Due: ${r.dueAt})`)
            .join('\n');
          return `Found ${result.data.length} reminders:\n${reminders}`;
        } else {
          return `No reminders found matching "${args.query}"`;
        }
      },
    },

    {
      name: 'update_reminder',
      description: 'Update an existing reminder',
      parameters: {
        reminderId: {
          type: 'string',
          description: 'Reminder ID',
        },
        title: {
          type: 'string',
          description: 'New title',
          optional: true,
        },
        dueAt: {
          type: 'string',
          description: 'New due date/time',
          optional: true,
        },
        notes: {
          type: 'string',
          description: 'New notes',
          optional: true,
        },
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        if (!args.reminderId) {
          return 'Error: Reminder ID is required';
        }

        const userId = args.userId || this.config.defaultUserId;
        console.log(`[Reminder Skill] Updating reminder ${args.reminderId}`);
        
        const updates = {};
        if (args.title) updates.title = args.title;
        if (args.dueAt) updates.dueAt = args.dueAt;
        if (args.notes) updates.notes = args.notes;

        const result = await this.apiCall(
          `/api/reminders/update/${args.reminderId}`,
          {
            method: 'PUT',
            body: JSON.stringify({ ...updates, userId }),
          }
        );
        
        if (result.success) {
          return `✅ Reminder updated: "${result.data.title}"`;
        } else {
          return `Error: ${result.error || 'Failed to update reminder'}`;
        }
      },
    },

    {
      name: 'complete_reminder',
      description: 'Mark a reminder as completed',
      parameters: {
        reminderId: {
          type: 'string',
          description: 'Reminder ID',
        },
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        if (!args.reminderId) {
          return 'Error: Reminder ID is required';
        }

        const userId = args.userId || this.config.defaultUserId;
        console.log(`[Reminder Skill] Marking reminder ${args.reminderId} as complete`);
        
        const result = await this.apiCall(
          `/api/reminders/complete/${args.reminderId}`,
          {
            method: 'POST',
            body: JSON.stringify({ userId }),
          }
        );
        
        if (result.success) {
          return `✅ Reminder marked as complete: "${result.data.title}"`;
        } else {
          return `Error: ${result.error || 'Failed to complete reminder'}`;
        }
      },
    },

    {
      name: 'delete_reminder',
      description: 'Delete a reminder',
      parameters: {
        reminderId: {
          type: 'string',
          description: 'Reminder ID',
        },
        userId: {
          type: 'string',
          description: 'User ID (email)',
          optional: true,
        },
      },
      async execute(context, args) {
        if (!args.reminderId) {
          return 'Error: Reminder ID is required';
        }

        const userId = args.userId || this.config.defaultUserId;
        console.log(`[Reminder Skill] Deleting reminder ${args.reminderId}`);
        
        const result = await this.apiCall(
          `/api/reminders/delete/${args.reminderId}`,
          {
            method: 'DELETE',
            body: JSON.stringify({ userId }),
          }
        );
        
        if (result.success) {
          return `✅ Reminder deleted`;
        } else {
          return `Error: ${result.error || 'Failed to delete reminder'}`;
        }
      },
    },
  ],

  // Optional: Scheduled tasks that run periodically
  schedules: [
    {
      name: 'daily_briefing',
      cron: '0 8 * * *', // 8 AM daily
      description: 'Send daily reminder briefing',
      async execute(context) {
        console.log('[Reminder Skill] Running daily briefing');
        const summaryTool = this.tools.find(t => t.name === 'get_reminders_summary');
        const result = await summaryTool.execute(context, {});
        
        // Send to OpenClaw context (it will notify user via their chat app)
        return {
          type: 'notification',
          title: '📅 Daily Reminder Briefing',
          message: result,
          priority: 'normal',
        };
      },
    },
  ],

  // Setup instructions
  setup() {
    console.log('🦞 AI Reminder Skill loaded!');
    console.log(`API Endpoint: ${this.config.apiUrl}`);
    console.log(`Default User: ${this.config.defaultUserId}`);
    console.log('Ready to manage reminders!');
  },
};

export default reminderSkill;
