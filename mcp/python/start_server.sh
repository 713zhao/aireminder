#!/usr/bin/env bash
cd "$(dirname "$0")"
source venv/bin/activate
exec uvicorn mcp_server_lite:app --host 127.0.0.1 --port 8000 "$@"
