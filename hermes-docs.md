# Hermes Agent

Hermes Agent is a self-improving AI agent built by Nous Research that features a built-in learning loop, creating skills from experience, improving them during use, and building a deepening model of who you are across sessions. It supports multiple LLM providers (Nous Portal, OpenRouter, OpenAI, Anthropic, z.ai/GLM, Kimi/Moonshot, MiniMax) and can run on hardware ranging from a $5 VPS to GPU clusters, with serverless options that cost nearly nothing when idle.

The agent provides a full terminal interface with multiline editing, slash-command autocomplete, and streaming tool output. It integrates with multiple messaging platforms (Telegram, Discord, Slack, WhatsApp, Signal, Email) through a unified gateway, supports scheduled automations via a built-in cron scheduler, and can delegate tasks to parallel subagents. The tool system includes 40+ tools for terminal operations, file manipulation, web search, browser automation, vision analysis, and more.

## AIAgent Class

The AIAgent class is the core conversation loop that manages tool calling, response handling, and message history. It supports configurable model parameters, multiple providers, toolset filtering, and callbacks for progress notifications.

```python
from run_agent import AIAgent

# Basic usage - simple chat interface
agent = AIAgent(
    model="anthropic/claude-sonnet-4-20250514",
    max_iterations=90
)
response = agent.chat("What files are in the current directory?")
print(response)

# Advanced usage with full configuration
agent = AIAgent(
    base_url="https://openrouter.ai/api/v1",
    api_key="sk-or-xxx",
    model="anthropic/claude-opus-4-20250514",
    max_iterations=50,
    enabled_toolsets=["terminal", "file", "web"],
    disabled_toolsets=["browser"],
    save_trajectories=True,
    quiet_mode=False,
    platform="cli",
    tool_progress_callback=lambda name, preview: print(f"Tool: {name}"),
    reasoning_config={"effort": "medium"},
    max_tokens=4096,
)

# Full conversation interface with history management
result = agent.run_conversation(
    user_message="Create a Python script that fetches weather data",
    system_message="You are a helpful coding assistant",
    conversation_history=[
        {"role": "user", "content": "Hi!"},
        {"role": "assistant", "content": "Hello! How can I help?"}
    ],
    task_id="unique-session-id"
)
print(result["final_response"])
print(f"Messages exchanged: {len(result['messages'])}")
```

## Tool Registry System

The tool registry is a central system where all tools self-register their schemas, handlers, and availability checks. Tools are organized into toolsets that can be enabled or disabled per session or platform.

```python
from tools.registry import registry

# Register a new tool
def check_api_available() -> bool:
    return bool(os.getenv("MY_API_KEY"))

def my_tool_handler(args: dict, task_id: str = None) -> str:
    param = args.get("param", "")
    # Perform tool operation
    return json.dumps({"success": True, "result": f"Processed: {param}"})

registry.register(
    name="my_tool",
    toolset="custom",
    schema={
        "name": "my_tool",
        "description": "A custom tool that processes data",
        "parameters": {
            "type": "object",
            "properties": {
                "param": {"type": "string", "description": "Input parameter"}
            },
            "required": ["param"]
        }
    },
    handler=lambda args, **kw: my_tool_handler(args, task_id=kw.get("task_id")),
    check_fn=check_api_available,
    requires_env=["MY_API_KEY"],
)

# Query registered tools
all_tools = registry.get_all_tool_names()
toolset = registry.get_toolset_for_tool("terminal")
available = registry.check_toolset_requirements()
```

## Tool Definitions and Dispatch

The model_tools module provides the public API for getting tool definitions and dispatching tool calls. It handles toolset filtering, availability checking, and error wrapping.

```python
from model_tools import (
    get_tool_definitions,
    handle_function_call,
    check_toolset_requirements,
    get_all_tool_names,
)

# Get tool definitions for API calls with filtering
tools = get_tool_definitions(
    enabled_toolsets=["terminal", "file", "web"],
    disabled_toolsets=None,
    quiet_mode=True
)
# Returns: [{"type": "function", "function": {"name": "terminal", ...}}, ...]

# Dispatch a tool call
result = handle_function_call(
    function_name="terminal",
    function_args={"command": "ls -la", "timeout": 30000},
    task_id="session-123",
)
print(json.loads(result))  # {"stdout": "...", "exit_code": 0}

# Check which toolsets are available
requirements = check_toolset_requirements()
# {"terminal": True, "browser": False, "web": True, ...}

# Get all registered tool names
tool_names = get_all_tool_names()
# ["terminal", "read_file", "write_file", "web_search", ...]
```

## Terminal Tool

The terminal tool executes shell commands with support for multiple backends (local, Docker, SSH, Modal, Daytona, Singularity), background execution, and automatic cleanup.

```python
from tools.terminal_tool import terminal_tool

# Execute a simple command
result = terminal_tool(
    command="git status",
    task_id="my-task",
    timeout=30000
)
print(json.loads(result))
# {"stdout": "On branch main\n...", "stderr": "", "exit_code": 0}

# Run a command in the background
result = terminal_tool(
    command="python server.py",
    background=True,
    task_id="server-task",
    check_interval=5  # Check every 5 seconds
)
# {"background": true, "pid": 12345, "process_id": "proc-xxx"}

# Environment configuration via environment variables
# TERMINAL_ENV: "local" | "docker" | "modal" | "ssh" | "daytona" | "singularity"
# TERMINAL_CWD: Working directory
# TERMINAL_TIMEOUT: Default timeout in ms
# TERMINAL_DOCKER_IMAGE: Docker image for container backend
```

## File Operations

File tools provide read, write, patch, and search operations that work across all terminal backends (local, Docker, SSH, etc.).

```python
from tools.file_tools import (
    read_file_tool,
    write_file_tool,
    patch_tool,
    search_tool,
)

# Read a file with pagination
result = read_file_tool(
    path="/path/to/file.py",
    offset=1,      # Start from line 1
    limit=100,     # Read 100 lines
    task_id="default"
)
data = json.loads(result)
print(data["content"])
print(f"Total lines: {data['total_lines']}")

# Write content to a file
result = write_file_tool(
    path="/path/to/output.txt",
    content="Hello, World!\nLine 2",
    task_id="default"
)

# Patch a file using string replacement
result = patch_tool(
    mode="replace",
    path="/path/to/file.py",
    old_string="def old_function():",
    new_string="def new_function():",
    replace_all=False,
    task_id="default"
)

# Search for content in files
result = search_tool(
    pattern="TODO|FIXME",
    target="content",
    path="./src",
    file_glob="*.py",
    limit=50,
    context=2,  # Lines of context
    task_id="default"
)
```

## Browser Automation

Browser tools provide web automation using either local Chromium (default) or Browserbase cloud service. The tool uses accessibility trees for LLM-friendly page representation.

```python
from tools.browser_tool import (
    browser_navigate,
    browser_snapshot,
    browser_click,
    browser_type,
    browser_scroll,
)

# Navigate to a URL
result = browser_navigate(
    url="https://example.com",
    task_id="browser-session"
)
# Returns page snapshot with element references (@e1, @e2, etc.)

# Get current page snapshot
snapshot = browser_snapshot(
    task_id="browser-session",
    user_task="Find the login button"  # Optional context for summarization
)

# Interact with elements using ref selectors
browser_click(ref="@e5", task_id="browser-session")
browser_type(ref="@e3", text="username@example.com", task_id="browser-session")
browser_scroll(direction="down", amount=500, task_id="browser-session")

# Environment configuration
# BROWSERBASE_API_KEY: Enable cloud mode with Browserbase
# BROWSERBASE_PROJECT_ID: Required for cloud mode
# BROWSER_INACTIVITY_TIMEOUT: Session cleanup timeout (default 300s)
```

## Skills System

Skills are procedural memories that provide domain-specific instructions to the agent. They follow a progressive disclosure architecture with metadata, full instructions, and linked reference files.

```python
from tools.skills_tool import skills_list, skill_view

# List all available skills with metadata
result = skills_list()
skills = json.loads(result)
for skill in skills["skills"]:
    print(f"{skill['name']}: {skill['description']}")

# View a skill's full content
result = skill_view(skill_name="axolotl")
# Returns full SKILL.md content with instructions

# View a reference file within a skill
result = skill_view(
    skill_name="axolotl",
    file_path="references/dataset-formats.md"
)

# Skill directory structure:
# ~/.hermes/skills/
# ├── my-skill/
# │   ├── SKILL.md           # Main instructions (required)
# │   ├── references/        # Supporting documentation
# │   └── templates/         # Output templates
```

## Memory System

The memory tool provides persistent curated memory across sessions with two stores: MEMORY.md for agent notes and USER.md for user information.

```python
from tools.memory_tool import MemoryStore

# Initialize and load memory
store = MemoryStore(
    memory_char_limit=2200,
    user_char_limit=1375
)
store.load_from_disk()

# Add a memory entry
result = store.add(
    target="memory",  # or "user"
    content="The project uses pytest for testing with conftest.py fixtures"
)

# Replace an existing entry
result = store.replace(
    target="memory",
    old_text="uses pytest",  # Unique substring to find
    new_content="The project uses pytest with pytest-xdist for parallel testing"
)

# Remove an entry
result = store.remove(
    target="user",
    text="prefers dark mode"  # Unique substring to match
)

# Read current entries
result = store.read(target="memory")
# {"entries": [...], "usage": "1500/2200", "count": 5}

# Get system prompt snapshot (frozen at session start)
memory_prompt = store.get_system_prompt_section()
```

## Messaging Gateway

The gateway runner manages connections to multiple messaging platforms (Telegram, Discord, Slack, WhatsApp, Signal, Email) with unified session management.

```python
# Start gateway from CLI
# hermes gateway

# Or programmatically
from gateway.run import GatewayRunner, start_gateway
from gateway.config import load_gateway_config

# Load configuration
config = load_gateway_config()

# Create and run gateway
runner = GatewayRunner(config)
await runner.start()

# Gateway environment variables
# TELEGRAM_BOT_TOKEN: Telegram bot token
# DISCORD_BOT_TOKEN: Discord bot token
# SLACK_BOT_TOKEN: Slack bot token
# WHATSAPP_PHONE_NUMBER: WhatsApp phone number
# SIGNAL_PHONE_NUMBER: Signal phone number

# Platform-specific session handling
# Sessions are isolated per chat/channel
# Voice memos are auto-transcribed
# Media files are processed and attached
```

## Delegate Tool (Subagents)

The delegate tool spawns child AIAgent instances for parallel task execution with isolated context, restricted toolsets, and separate terminal sessions.

```python
from tools.delegate_tool import delegate_task

# Single task delegation
result = delegate_task(
    goal="Search the codebase for all TODO comments and create a summary",
    context="Focus on high-priority items in the src/ directory",
    toolsets=["terminal", "file"],  # Restricted toolset
    max_iterations=30,
    task_id="parent-session"
)
# Child executes independently and returns summary

# Batch parallel delegation
result = delegate_task(
    tasks=[
        {"goal": "Run unit tests", "toolsets": ["terminal"]},
        {"goal": "Check code style", "toolsets": ["terminal"]},
        {"goal": "Generate documentation", "toolsets": ["file", "terminal"]},
    ],
    max_concurrent=3,
    task_id="parent-session"
)
# Returns results from all parallel tasks

# Blocked tools in children:
# - delegate_task (no recursive delegation)
# - clarify (no user interaction)
# - memory (no shared memory writes)
# - send_message (no cross-platform effects)
```

## Cron Scheduler

The built-in cron scheduler executes jobs at specified times with delivery to any configured messaging platform.

```python
from cron.jobs import add_job, list_jobs, remove_job, get_due_jobs
from cron.scheduler import tick

# Add a scheduled job
job = add_job(
    name="daily-report",
    schedule="0 9 * * *",  # 9 AM daily (cron format)
    prompt="Generate a summary of yesterday's commits",
    deliver="telegram",  # or "discord", "slack", "origin", "local"
    origin={
        "platform": "telegram",
        "chat_id": "123456789"
    }
)

# List all jobs
jobs = list_jobs()
for job in jobs:
    print(f"{job['name']}: {job['schedule']} -> {job['deliver']}")

# Remove a job
remove_job(job_id="job-xxx")

# The gateway runs tick() every 60 seconds automatically
# For manual execution:
tick()  # Executes all due jobs
```

## Batch Processing

The batch runner provides parallel processing for running the agent across multiple prompts with checkpointing, trajectory saving, and tool usage statistics.

```bash
# Run batch processing from CLI
python batch_runner.py \
    --dataset_file=prompts.jsonl \
    --batch_size=10 \
    --run_name=my_experiment \
    --model="anthropic/claude-sonnet-4-20250514" \
    --distribution=default

# Resume an interrupted run
python batch_runner.py \
    --dataset_file=prompts.jsonl \
    --run_name=my_experiment \
    --resume

# Dataset format (JSONL):
# {"prompt": "Write a function to sort a list"}
# {"prompt": "Explain quicksort algorithm"}
```

```python
from batch_runner import run_batch, load_dataset

# Load dataset
prompts = load_dataset("prompts.jsonl")

# Run batch with custom configuration
results = run_batch(
    prompts=prompts,
    batch_size=10,
    run_name="experiment-001",
    model="anthropic/claude-sonnet-4-20250514",
    enabled_toolsets=["terminal", "file"],
    save_trajectories=True,
    checkpoint_interval=5,
)

# Results include tool usage statistics
for result in results:
    print(f"Prompt: {result['prompt'][:50]}...")
    print(f"Response: {result['response'][:100]}...")
    print(f"Tool calls: {result['tool_stats']}")
```

## CLI Commands

The Hermes CLI provides commands for configuration, model selection, gateway management, and interactive chat.

```bash
# Start interactive chat
hermes

# Model and provider management
hermes model                    # Interactive model selection
hermes model set gpt-4o        # Set default model
hermes provider                 # List/configure providers

# Tool and skill management
hermes tools                    # Configure enabled tools (curses UI)
hermes skills browse            # Browse Skills Hub
hermes skills sync              # Sync bundled skills

# Gateway operations
hermes gateway                  # Start messaging gateway
hermes gateway --platform telegram  # Start specific platform

# Configuration
hermes setup                    # Full setup wizard
hermes config set key value    # Set config value
hermes config get key          # Get config value
hermes doctor                   # Diagnose issues

# Session management
hermes sessions                 # List sessions
hermes resume <name>           # Resume named session

# Migration from OpenClaw
hermes claw migrate            # Interactive migration
hermes claw migrate --dry-run  # Preview migration

# Update
hermes update                  # Update to latest version
```

## Summary

Hermes Agent is designed for developers and power users who need a persistent, intelligent AI assistant that learns and improves over time. The primary use cases include: software development assistance with full codebase access, automated DevOps tasks via scheduled cron jobs, multi-platform customer support through the messaging gateway, research and data processing via batch runner, and building custom AI workflows using the skills system and tool registry.

Integration patterns follow a modular architecture where the AIAgent class serves as the core interface, tools self-register via the registry singleton, and the gateway manages platform-specific adapters. Custom tools can be added by creating a file in `tools/`, registering with the registry, and adding to a toolset in `toolsets.py`. The skin/theme engine allows visual customization via YAML files in `~/.hermes/skins/`. For production deployments, the agent supports Docker, Modal, and Daytona backends for isolated execution, with serverless options that minimize costs during idle periods.
