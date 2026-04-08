#!/usr/bin/env bash

# Source local config file if it exists
STU_AGENT_DIR="${STU_AGENT_DIR:-${HOME}/stu-agent}"
if [ -f "${STU_AGENT_DIR}/config" ]; then
	source ${STU_AGENT_DIR}/config
fi

CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"
CLAUDE_CONTAINER_CMD="${CLAUDE_CONTAINER_CMD:-claude-container}"
CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-auto}"
GIT_REPO="${GIT_REPO:-stu-agent}"
GIT_REPO_DIR="$PWD/$GIT_REPO"
GIT_FORK_URL="${GIT_FORK_URL:-git@github.com:${USER:-$(id -un)}/$GIT_REPO.git}"
GIT_UPSTREAM_URL="${GIT_UPSTREAM_URL:-https://github.com/jstuever/$GIT_REPO.git}"
GIT_UPSTREAM_BRANCH="${GIT_UPSTREAM_BRANCH:-main}"

usage() {
	echo "Usage: $(basename "$0") [setup|implement|review]" >&2
	exit 1
}

die() {
	echo "ERROR: $*" >&2
	exit 2
}

setup() {
	BRANCH="${BRANCH:-$(basename $PWD)}"

	# Create logs directory
	if [ ! -d "logs" ]; then
		mkdir -p "logs" || die "Unable to create directory: logs"
	fi

	# Clone the repository if not already cloned
	if [[ ! -d "$GIT_REPO_DIR" ]]; then
		git clone "$GIT_FORK_URL" "$GIT_REPO_DIR" || die "git clone failed"
	fi

	cd "$GIT_REPO_DIR" || die "Cannot cd to $GIT_REPO_DIR"

	# Add upstream remote if not already present
	if ! git remote get-url upstream &>/dev/null; then
		git remote add upstream "$GIT_UPSTREAM_URL" || die "Failed to add upstream remote"
	fi

	# Fetch all remotes
	git fetch --all --tags --prune || die "git fetch failed"

	# Check out the feature branch
	if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
		if [[ "$(git rev-parse --abbrev-ref HEAD)" != "$BRANCH" ]]; then
			git switch "$BRANCH" || die "git switch failed"
		fi
	else
		git switch -c "$BRANCH" "upstream/$GIT_UPSTREAM_BRANCH" || die "git switch -c failed"
	fi

	# Set up Claude configuration
	if ! grep -qxF ".claude/" ".git/info/exclude" 2>/dev/null; then
		echo ".claude/" >> ".git/info/exclude"
	fi

	if [ ! -d ".claude/commands" ]; then
		mkdir -p ".claude/commands" || die "failed to mkdir .claude/commands"
	fi

	cp $STU_AGENT_DIR/src/stu-agent/commands/* .claude/commands || die "unable to copy commands"

	# Copy the spec.md if it exists
	if [ -f ../spec.md ]; then
		cp ../spec.md .claude/spec.md || die "failed to copy spec.md"
	fi
}

git-stash() {
	git add .
	if ! git diff --cached --quiet; then
		git stash save --keep-index -m "${1}" || die "git stash push failed"
	fi
}

implement-spec() {
	local ts; ts=$(date +%Y%m%d%H%M%S)
	local log_file; log_file="$PWD/logs/$ts-implement-spec.log"

	cd "$GIT_REPO_DIR" || die "Cannot cd to $GIT_REPO_DIR"

	if [ ! -f .claude/spec.md ]; then
		die ".claude/spec.md not found"
	fi

	$CLAUDE_CONTAINER_CMD \
		--model "$CLAUDE_MODEL" \
		--permission-mode "$CLAUDE_PERMISSION_MODE" \
		--verbose --output-format stream-json \
		--print "/implement-spec @.claude/spec.md" \
	| tee -a "$log_file"

	git-stash "$ts-implement-spec"
}

pre-commit-review() {
	local ts; ts=$(date +%Y%m%d%H%M%S)
	local log_file; log_file="$PWD/logs/$ts-pre-commit-review.log"

	cd "$GIT_REPO_DIR" || die "Cannot cd to $GIT_REPO_DIR"

	$CLAUDE_CONTAINER_CMD \
		--model "$CLAUDE_MODEL" \
		--permission-mode "$CLAUDE_PERMISSION_MODE" \
		--verbose --output-format stream-json \
		--plugin-dir "/opt/ai-helpers/plugins/code-review" \
		--print "/code-review:pre-commit-review --resolve" \
	| tee -a "$log_file"

	git-stash "$ts-pre-commit-review"
}

# Parse arguments
COMMAND=""
while [[ $# -gt 0 ]]; do case $1 in
	--help)
		usage
		exit $?
		;;
	--dir)
		TESTDIR="$2"
		shift 2
		;;
	setup|implement|review)
		COMMAND="$1"
		shift
		;;
	*)
		usage
		;;
esac done

case "${COMMAND}" in
	"setup")
		setup
		;;
	"implement")
		implement-spec
		;;
	"review")
		pre-commit-review
		;;
	"")
		setup
		implement-spec
		pre-commit-review
		;;
esac
