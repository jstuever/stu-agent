# stu-agent
Agentic workflow proof of concept

## Overview
This repository provides a proof-of-concept agentic workflow that takes a `spec.md` as input and generates code to implement it, leaving changes staged for commit.

- `agent-container.sh`: Builds and runs the agent CLI in a container, leveraging [openshift-eng/ai-helpers](https://github.com/openshift-eng/ai-helpers). Executing the script without any arguments will provide a Claude CLI interface in the current working directory.
- `stu-agent.sh`: Sets up and executes the workflow. It prepares the Git repository, implements the supplied spec, and performs local code review and resolution. It creates stashed copies of changes at each step and logs the agent's output.
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

   STU_AGENT="${STU_AGENT:-opencode"}

   VERTEX_PROJECT_ID="${VERTEX_PROJECT_ID:-<YOUR_VERTEX_PROJECT_ID>}"
   VERTEX_REGION="${VERTEX_REGION:-<YOUR_VERTEX_REGION>}"

   GIT_REPO="${GIT_REPO:-<YOUR_GIT_REPO>}"
   GIT_UPSTREAM_URL="${GIT_UPSTREAM_URL:-<YOUR_UPSTREAM_GIT_REPO>}"
   EOF
   ```

3. **Build and set up agent-container**
   ```bash
   agent-container build
   agent-container auth
   ```
   Note: the auth parameter will generate gcloud authentication resources in `~/stu-agent/gcloud/`. It will open the web browser as part of the process. The end result is an application credential that will be passed into the agent-container for use by Claude.

4. **Use stu-agent to implement a spec**
   ```bash
   mkdir -p ~/stu-agent/work/myfeature
   cd ~/stu-agent/work/myfeature
   cp ~/my-existing-spec.md spec.md # Copy the spec you intend to implement.
   stu-agent
   ```
   Note: stu-agent without any arguments will perform `setup`, `implement`, and `review` steps in that order. Each step can also be called directly (i.e., `stu-agent implement`).
