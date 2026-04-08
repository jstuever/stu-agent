# stu-agent
Agentic workflow proof of concept

## Overview
This repository provides a proof-of-concept agentic workflow that takes a `spec.md` as input and generates code to implement it, leaving changes staged for commit.

- `claude-container.sh`: Builds and runs the Claude CLI in a container, leveraging [openshift-eng/ai-helpers](https://github.com/openshift-eng/ai-helpers).
- `stu-agent.sh`: Sets up and executes the workflow. It prepares the Git repository, implements the supplied spec, and performs local code review and resolution. It creates stashed copies of changes at each step and logs Claude's output.
- `implement-spec.md`: Provides the slash command used by `stu-agent.sh` during implementation.

## Getting Started

1. **Install stu-agent**
   This creates a `~/stu-agent/` folder, clones required repositories into `~/stu-agent/src/`, and symlinks scripts to `~/bin/` (if it exists).
   ```bash
   curl https://raw.githubusercontent.com/jstuever/stu-agent/main/scripts/install.sh | bash
   ```

2. **Create a Configuration**
   ```bash
   cat <<EOF > ~/stu-agent/config
   CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-bypassPermissions}"
   CLAUDE_PROJECT_ID="${CLAUDE_PROJECT_ID:-<YOUR_CLAUDE_PROJECT_ID>}"
   CLAUDE_REGION="${CLAUDE_REGION:-<YOUR_CLAUDE_REGION>}"

   GIT_REPO="${GIT_REPO:-<YOUR_GIT_REPO>}"
   GIT_UPSTREAM_URL="${GIT_UPSTREAM_URL:-<YOUR_UPSTREAM_GIT_REPO>}"
   EOF
   ```
   **Warning:** We currently use `bypassPermissions` for this proof of concept. For production, restrict permissions to acceptable actions only.
