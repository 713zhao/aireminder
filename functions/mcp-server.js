#!/usr/bin/env node

/**
 * MCP Server for AI Reminder - Main Entry Point
 * Provides access to user reminders through the Model Context Protocol
 *
 * Usage:
 *   node mcp-server.js
 *
 * The server communicates via stdin/stdout using the MCP protocol
 */

import {
  Server,
  StdioServerTransport,
} from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequest,
  ListResourcesRequest,
  ReadResourceRequest,
  ListToolsRequest,
} from '@modelcontextprotocol/sdk/types.js';

import { initializeFirebase, testConnection } from './firebase-config.js';
import * as remindersService from './reminders-service.js';
import {
  formatReminderForLLM,
  createSuccessResponse,
  createErrorResponse,
} from './utils.js';

// Get user ID from environment
const DEFAULT_USER_ID = process.env.USER_ID || 'user@example.com';
const DEBUG = process.env.DEBUG === 'true';

// Create MCP Server
const server = new Server({
  name: 'aireminder-mcp-server',
  version: '1.0.0',
});

/**
 * Handler for listing available resources
 */
server.setRequestHandler(ListResourcesRequest, async () => {
  return {
    resources: [
      {
        uri: `reminders://list/${DEFAULT_USER_ID}`,
        name: 'All Reminders',
        description: 'Complete list of all reminders for the user',
        mimeType: 'application/json',
      },
      {
        uri: `reminders://upcoming/${DEFAULT_USER_ID}/7`,
        name: 'Upcoming Reminders (7 days)',
        description: 'Reminders due in the next 7 days',
        mimeType: 'application/json',
      },
      {
        uri: `reminders://today/${DEFAULT_USER_ID}`,
        name: 'Today Reminders',
        description: 'Reminders due today',
        mimeType: 'application/json',
      },
      {
        uri: `reminders://overdue/${DEFAULT_USER_ID}`,
        name: 'Overdue Reminders',
        description: 'Reminders that are overdue',
        mimeType: 'application/json',
      },
      {
        uri: `reminders://summary/${DEFAULT_USER_ID}`,
        name: 'Reminders Summary',
        description: 'Summary statistics of user reminders',
        mimeType: 'application/json',
      },
      {
        uri: `reminders://shared/${DEFAULT_USER_ID}`,
        name: 'Shared Reminders',
        description: 'Reminders shared with the user by others',
        mimeType: 'application/json',
      },
    ],
  };
});

/**
 * Handler for reading resource content
 */
server.setRequestHandler(ReadResourceRequest, async (request) => {
  const uri = request.params.uri;

  try {
    // Parse URI: reminders://type/userId/optional-param
    const match = uri.match(/^reminders:\/\/([^\/]+)\/([^\/]+)(?:\/(.+))?$/);
    if (!match) {
      return {
        contents: [
          {
            uri,
            mimeType: 'application/json',
            text: JSON.stringify(
              createErrorResponse('INVALID_URI', 'Invalid resource URI format'),
              null,
              2
            ),
          },
        ],
      };
    }

    const [, type, userId, param] = match;
    let data;

    switch (type) {
      case 'list': {
        data = await remindersService.getAllReminders(userId);
        break;
      }

      case 'upcoming': {
        const days = parseInt(param) || 7;
        data = await remindersService.getUpcomingReminders(userId, days, {
          sortBy: 'priority',
        });
        break;
      }

      case 'today': {
        data = await remindersService.getTodayReminders(userId);
        break;
      }

      case 'overdue': {
        data = await remindersService.getOverdueReminders(userId);
        break;
      }

      case 'summary': {
        data = await remindersService.getRemindersSummary(userId);
        break;
      }

      case 'shared': {
        data = await remindersService.getSharedReminders(userId);
        break;
      }

      default:
        return {
          contents: [
            {
              uri,
              mimeType: 'application/json',
              text: JSON.stringify(
                createErrorResponse('UNKNOWN_TYPE', `Unknown resource type: ${type}`),
                null,
                2
              ),
            },
          ],
        };
    }

    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(createSuccessResponse(data), null, 2),
        },
      ],
    };
  } catch (error) {
    if (DEBUG) {
      console.error('[DEBUG] ReadResourceRequest error:', error);
    }
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(
            createErrorResponse('INTERNAL_ERROR', error.message),
            null,
            2
          ),
        },
      ],
    };
  }
});

/**
 * Handler for listing available tools
 */
server.setRequestHandler(ListToolsRequest, async () => {
  return {
    tools: [
      {
        name: 'list_reminders',
        description: 'Get all reminders for the authenticated user with optional filtering',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
            status: {
              type: 'string',
              enum: ['pending', 'completed', 'all'],
              description: 'Filter by reminder status',
              default: 'all',
            },
            limit: {
              type: 'number',
              description: 'Maximum number of reminders to return',
            },
          },
          required: [],
        },
      },
      {
        name: 'get_upcoming_reminders',
        description: 'Get reminders due in the next N days, sorted by priority',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
            days: {
              type: 'number',
              description: 'Number of days to look ahead',
              default: 7,
            },
            sortBy: {
              type: 'string',
              enum: ['dueDate', 'priority'],
              description: 'Sort order for results',
              default: 'priority',
            },
            includeCompleted: {
              type: 'boolean',
              description: 'Include completed reminders',
              default: false,
            },
          },
          required: [],
        },
      },
      {
        name: 'get_today_reminders',
        description: 'Get all reminders due today',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
            includeCompleted: {
              type: 'boolean',
              description: 'Include completed reminders',
              default: false,
            },
          },
          required: [],
        },
      },
      {
        name: 'get_overdue_reminders',
        description: 'Get all overdue (pending) reminders',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
          },
          required: [],
        },
      },
      {
        name: 'get_reminder_details',
        description: 'Get detailed information about a specific reminder',
        inputSchema: {
          type: 'object',
          properties: {
            reminderId: {
              type: 'string',
              description: 'The ID of the reminder to fetch',
            },
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
          },
          required: ['reminderId'],
        },
      },
      {
        name: 'search_reminders',
        description: 'Search reminders by title or notes',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query string',
            },
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
            status: {
              type: 'string',
              enum: ['pending', 'completed', 'all'],
              description: 'Filter by status',
              default: 'all',
            },
            limit: {
              type: 'number',
              description: 'Maximum number of results',
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'get_reminders_summary',
        description: 'Get a summary of reminder statistics',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
          },
          required: [],
        },
      },
      {
        name: 'get_shared_reminders',
        description: 'Get reminders that are shared with the user by others',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
          },
          required: [],
        },
      },
      {
        name: 'add_reminder',
        description: 'Create a new reminder',
        inputSchema: {
          type: 'object',
          properties: {
            title: {
              type: 'string',
              description: 'Reminder title (required)',
            },
            notes: {
              type: 'string',
              description: 'Optional notes or description',
            },
            dueAt: {
              type: 'string',
              description: 'Due date/time in ISO format (e.g., 2026-02-22T10:00:00Z)',
            },
            recurrence: {
              type: 'string',
              description: 'Recurrence pattern (daily, weekly, monthly, etc.)',
            },
            remindBeforeMinutes: {
              type: 'number',
              description: 'Minutes before due date to remind (default: 10)',
            },
            recurrenceEndDate: {
              type: 'string',
              description: 'End date for recurring reminders in ISO format',
            },
            weeklyDays: {
              type: 'array',
              items: { type: 'number' },
              description: 'Days of week for weekly recurrence (1=Monday, 7=Sunday)',
            },
            sharedWith: {
              type: 'array',
              items: { type: 'string' },
              description: 'List of email addresses to share this reminder with',
            },
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
          },
          required: ['title'],
        },
      },
      {
        name: 'edit_reminder',
        description: 'Update an existing reminder',
        inputSchema: {
          type: 'object',
          properties: {
            reminderId: {
              type: 'string',
              description: 'The ID of the reminder to update (required)',
            },
            title: {
              type: 'string',
              description: 'New reminder title',
            },
            notes: {
              type: 'string',
              description: 'Updated notes or description',
            },
            dueAt: {
              type: 'string',
              description: 'Updated due date/time in ISO format',
            },
            recurrence: {
              type: 'string',
              description: 'Updated recurrence pattern',
            },
            remindBeforeMinutes: {
              type: 'number',
              description: 'Updated reminder time in minutes',
            },
            recurrenceEndDate: {
              type: 'string',
              description: 'Updated end date for recurring reminders',
            },
            weeklyDays: {
              type: 'array',
              items: { type: 'number' },
              description: 'Updated days of week for weekly recurrence',
            },
            sharedWith: {
              type: 'array',
              items: { type: 'string' },
              description: 'Updated list of email addresses to share with',
            },
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
          },
          required: ['reminderId'],
        },
      },
      {
        name: 'delete_reminder',
        description: 'Delete a reminder',
        inputSchema: {
          type: 'object',
          properties: {
            reminderId: {
              type: 'string',
              description: 'The ID of the reminder to delete (required)',
            },
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
          },
          required: ['reminderId'],
        },
      },
      {
        name: 'complete_reminder',
        description: 'Mark a reminder as completed',
        inputSchema: {
          type: 'object',
          properties: {
            reminderId: {
              type: 'string',
              description: 'The ID of the reminder to complete (required)',
            },
            userId: {
              type: 'string',
              description: 'User ID or email (optional, uses USER_ID env var if not provided)',
            },
          },
          required: ['reminderId'],
        },
      },
    ],
  };
});

/**
 * Handler for calling tools
 */
server.setRequestHandler(CallToolRequest, async (request) => {
  const { name, arguments: args } = request.params;
  const userId = args.userId || DEFAULT_USER_ID;

  try {
    let result;

    switch (name) {
      case 'list_reminders': {
        result = await remindersService.getAllReminders(userId, {
          status: args.status || 'all',
          limit: args.limit,
        });
        break;
      }

      case 'get_upcoming_reminders': {
        result = await remindersService.getUpcomingReminders(
          userId,
          args.days || 7,
          {
            sortBy: args.sortBy || 'priority',
            includeCompleted: args.includeCompleted || false,
          }
        );
        break;
      }

      case 'get_today_reminders': {
        result = await remindersService.getTodayReminders(userId, {
          includeCompleted: args.includeCompleted || false,
        });
        break;
      }

      case 'get_overdue_reminders': {
        result = await remindersService.getOverdueReminders(userId);
        break;
      }

      case 'get_reminder_details': {
        result = await remindersService.getReminderById(args.reminderId, userId);
        break;
      }

      case 'search_reminders': {
        result = await remindersService.searchUserReminders(
          userId,
          args.query,
          {
            status: args.status || 'all',
            limit: args.limit,
          }
        );
        break;
      }

      case 'get_reminders_summary': {
        result = await remindersService.getRemindersSummary(userId);
        break;
      }

      case 'get_shared_reminders': {
        result = await remindersService.getSharedReminders(userId);
        break;
      }

      case 'add_reminder': {
        result = await remindersService.createReminder(userId, args.title, {
          notes: args.notes,
          dueAt: args.dueAt,
          recurrence: args.recurrence,
          remindBeforeMinutes: args.remindBeforeMinutes,
          recurrenceEndDate: args.recurrenceEndDate,
          weeklyDays: args.weeklyDays,
          sharedWith: args.sharedWith,
        });
        break;
      }

      case 'edit_reminder': {
        result = await remindersService.updateReminder(args.reminderId, userId, {
          title: args.title,
          notes: args.notes,
          dueAt: args.dueAt,
          recurrence: args.recurrence,
          remindBeforeMinutes: args.remindBeforeMinutes,
          recurrenceEndDate: args.recurrenceEndDate,
          weeklyDays: args.weeklyDays,
          sharedWith: args.sharedWith,
        });
        break;
      }

      case 'delete_reminder': {
        result = await remindersService.deleteReminder(args.reminderId, userId);
        break;
      }

      case 'complete_reminder': {
        result = await remindersService.completeReminder(args.reminderId, userId);
        break;
      }

      default:
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(
                createErrorResponse('UNKNOWN_TOOL', `Unknown tool: ${name}`),
                null,
                2
              ),
            },
          ],
        };
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(createSuccessResponse(result), null, 2),
        },
      ],
    };
  } catch (error) {
    if (DEBUG) {
      console.error('[DEBUG] CallToolRequest error:', error);
    }
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(
            createErrorResponse('TOOL_ERROR', error.message),
            null,
            2
          ),
        },
      ],
      isError: true,
    };
  }
});

/**
 * Main function to start the server
 */
async function main() {
  try {
    // Initialize Firebase
    if (DEBUG) {
      console.error('[DEBUG] Initializing Firebase...');
    }
    initializeFirebase();

    // Test connection
    if (DEBUG) {
      console.error('[DEBUG] Testing Firebase connection...');
      const connected = await testConnection();
      if (!connected) {
        console.error('WARNING: Could not verify Firebase connection');
      }
    }

    // Start MCP server with stdio transport
    const transport = new StdioServerTransport();
    await server.connect(transport);

    if (DEBUG) {
      console.error('[DEBUG] MCP Server started successfully on stdio transport');
    }
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

// Start the server
main().catch(error => {
  console.error('Unexpected error:', error);
  process.exit(1);
});

// Handle graceful shutdown
process.on('SIGINT', async () => {
  if (DEBUG) {
    console.error('[DEBUG] Shutting down gracefully...');
  }
  process.exit(0);
});

process.on('SIGTERM', async () => {
  if (DEBUG) {
    console.error('[DEBUG] Shutting down gracefully...');
  }
  process.exit(0);
});
