#!/bin/sh

# Source local config file if it exists
STU_AGENT_DIR="${STU_AGENT_DIR:-$HOME/stu-agent}"
if [ -f "$STU_AGENT_DIR/config" ]; then
	source $STU_AGENT_DIR/config
fi

AI_HELPERS_REPO="${AI_HELPERS:-https://github.com/openshift-eng/ai-helpers.git}"
CLAUDE_PROJECT_ID="${CLAUDE_PROJECT_ID:-}"
CLAUDE_REGION="${CLAUDE_REGION:-}"
PULL_SECRET="${PULL_SECRET:-$STU_AGENT_DIR/pull-secret.json}"

export CLOUDSDK_CONFIG="$STU_AGENT_DIR/claude.config/gcloud"

usage() {
	echo "Usage: $(basename $0) [build|auth|help]"
}

auth() {
	gcloud init --project "$CLAUDE_PROJECT_ID"
	gcloud auth application-default login
	gcloud auth application-default set-quota-project cloudability-it-gemini
}

build() {
	if [ ! -f $XDG_RUNTIME_DIR/containers/auth.json ]; then
		mkdir -p $XDG_RUNTIME_DIR/containers
		cp $PULL_SECRET $XDG_RUNTIME_DIR/containers/auth.json
	fi
	if [ ! -d $STU_AGENT_DIR/src/ai-helpers ]; then
		git clone $AI_HELPERS_REPO
	fi
	cd $STU_AGENT_DIR/src/ai-helpers
	podman build -f images/Dockerfile -t ai-helpers .
}

case "${1-}" in
	"auth")
		auth
		exit
	;;
	"build")
		build
		exit
	;;
	"help")
		usage
		exit
	;;
esac

if [[ "$PWD" == "$HOME" ]]; then
	echo "You should not use claude on your home directory"
	usage
	exit 1
fi

if [ -z "$CLAUDE_PROJECT_ID" ]; then
	echo "You must set CLAUDE_PORJECT_ID envornmnet variable"
	usage
	exit 1
fi

if [ -z "$CLAUDE_REGION" ]; then
	echo "You must set CLAUDE_REGION envornmnet variable"
	usage
	exit 1
fi

podman run -it --rm \
	-e CLAUDE_CODE_USE_VERTEX=1 \
	-e CLOUD_ML_REGION=$CLAUDE_REGION \
	-e ANTHROPIC_VERTEX_PROJECT_ID=$CLAUDE_PROJECT_ID \
	-e CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
	-v $STU_AGENT_DIR/claude.config:/home/claude/.config:ro,z \
	-v $PWD:/workspace:z \
	-w /workspace \
	--userns=keep-id \
	ai-helpers "${@:-claude}"
