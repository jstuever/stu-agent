#!/usr/bin/env bash

# Source local config file if it exists
STU_AGENT_DIR="${STU_AGENT_DIR:-${HOME}/stu-agent}"
if [ -f "${STU_AGENT_DIR}/config" ]; then
	source ${STU_AGENT_DIR}/config
fi

# Source local config file if it exists
if [ -f "$PWD/config" ]; then
	source $PWD/config
fi

STU_AGENT="${STU_AGENT:-claude}"
AGENT_CONTAINER_CMD="${AGENT_CONTAINER_CMD:-agent-container}"
AGENT_MODEL="${AGENT_MODEL:-}"
AGENT_PERMISSION_MODE="${AGENT_PERMISSION_MODE:-auto}"
GIT_REPO="${GIT_REPO:-stu-agent}"
GIT_REPO_DIR="$PWD/$GIT_REPO"
GIT_REPO_URL="${GIT_REPO_URL:-git@github.com:${USER:-$(id -un)}/$GIT_REPO.git}"
GIT_UPSTREAM_URL="${GIT_UPSTREAM_URL:-https://github.com/jstuever/$GIT_REPO.git}"
GIT_UPSTREAM_BRANCH="${GIT_UPSTREAM_BRANCH:-main}"
LOGS_DIR="$PWD/logs"

ARG_AGENT_MODEL=""
if [[ -n "${AGENT_MODEL}" ]]; then
	ARG_AGENT_MODEL="--model $AGENT_MODEL"
fi

export AGENT_CONTAINER_GO_CACHE="${PWD}/go-cache"

TIME_CMD=$(which time)
TIME_FORMAT="\n{\"time\":{\"real_time_seconds\":%e}}"

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

	# Create go-cache directory
	if [ ! -d "go-cache" ]; then
		mkdir -p "go-cache" || die "Unable to create directory: go-cache"
	fi

	# Clone the repository if not already cloned
	if [[ ! -d "$GIT_REPO_DIR" ]]; then
		git clone "$GIT_REPO_URL" "$GIT_REPO_DIR" || die "git clone failed"
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

	cp $STU_AGENT_DIR/src/commands/* .claude/commands || die "unable to copy commands"

	# Set up opencode configuration
	if ! grep -qxF ".opencode/" ".git/info/exclude" 2>/dev/null; then
		echo ".opencode/" >> ".git/info/exclude"
	fi

	if [ ! -d ".opencode/commands" ]; then
		mkdir -p ".opencode/commands" || die "failed to mkdir .opencode/commands"
	fi

	cp $STU_AGENT_DIR/src/commands/* .opencode/commands || die "unable to copy commands"

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
	local log_file; log_file="$LOGS_DIR/$ts-implement-spec.log"
	local time_cmd; time_cmd=""
	if [[ -n "${TIME_CMD}" ]]; then
		time_cmd="${TIME_CMD} -f ${TIME_FORMAT} -a -o ${log_file}"
	fi

	cd "$GIT_REPO_DIR" || die "Cannot cd to $GIT_REPO_DIR"

	if [ ! -f .claude/spec.md ]; then
		die ".claude/spec.md not found"
	fi

	case "${STU_AGENT:-}" in
		"claude")
			$time_cmd $AGENT_CONTAINER_CMD \
				$ARG_AGENT_MODEL \
				--permission-mode "$AGENT_PERMISSION_MODE" \
				--verbose --output-format stream-json \
				--print "/implement-spec @.claude/spec.md" \
			| tee -a "$log_file"
		;;
		"opencode")
			$time_cmd $AGENT_CONTAINER_CMD run \
				$ARG_AGENT_MODEL \
				--dangerously-skip-permissions \
				--format json \
				--command "implement-spec" "@.opencode/spec.md" \
			| tee -a "$log_file"
		;;
		esac

	git-stash "$ts-implement-spec"
}

pre-commit-review() {
	local ts; ts=$(date +%Y%m%d%H%M%S)
	local log_file; log_file="$LOGS_DIR/$ts-pre-commit-review.log"
	local time_cmd; time_cmd=""
	if [[ -n "${TIME_CMD}" ]]; then
		time_cmd="${TIME_CMD} -f ${TIME_FORMAT} -a -o ${log_file}"
	fi

	cd "$GIT_REPO_DIR" || die "Cannot cd to $GIT_REPO_DIR"

	case "${STU_AGENT:-}" in
		"claude")
			$time_cmd $AGENT_CONTAINER_CMD \
				$ARG_AGENT_MODEL \
				--permission-mode "$AGENT_PERMISSION_MODE" \
				--verbose --output-format stream-json \
				--plugin-dir "/opt/ai-helpers/plugins/code-review" \
				--print "/code-review:pre-commit-review --resolve" \
			| tee -a "$log_file"
		;;
		"opencode")
			$time_cmd $AGENT_CONTAINER_CMD \
				$ARG_AGENT_MODEL \
				--dangerously-skip-permissions \
				--format json \
				--command "pre-commit-review" "--resolve" \
			| tee -a "$log_file"
		;;
	esac

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
