#!/bin/sh

# Source local config file if it exists
STU_AGENT_DIR="${STU_AGENT_DIR:-$HOME/stu-agent}"
if [ -f "$STU_AGENT_DIR/config" ]; then
	source $STU_AGENT_DIR/config
fi

AI_HELPERS_REPO="${AI_HELPERS:-https://github.com/openshift-eng/ai-helpers.git}"
PULL_SECRET="${PULL_SECRET:-$STU_AGENT_DIR/pull-secret.json}"

# Configure agent
STU_AGENT="${STU_AGENT:-claude}"

# Configure Claude
VORTEX_PROJECT_ID="${VORTEX_PROJECT_ID:-}"
VORTEX_REGION="${VORTEX_REGION:-}"
export CLOUDSDK_CONFIG="$STU_AGENT_DIR/gcloud"

# Configure Go cache
GO_CACHE_ARG=""
if [[ -n "$AGENT_CONTAINER_GO_CACHE" ]]; then
	GO_CACHE_ARG=" --volume $AGENT_CONTAINER_GO_CACHE:/go/.cache:z"
fi

usage() {
	echo "Usage: $(basename $0) [build|auth|help]"
}

auth() {
	# Authenticate to gcloud
	gcloud init --project "$VORTEX_PROJECT_ID"
	gcloud auth application-default login
	gcloud auth application-default set-quota-project cloudability-it-gemini
}

build() {
	if [ ! -f $XDG_RUNTIME_DIR/containers/auth.json ]; then
		mkdir -p $XDG_RUNTIME_DIR/containers
		cp $PULL_SECRET $XDG_RUNTIME_DIR/containers/auth.json
	fi
	if [ ! -d $STU_AGENT_DIR/src/ai-helpers ]; then
		git clone $AI_HELPERS_REPO $STU_AGENT_DIR/src/ai-helpers
	fi
	cd $STU_AGENT_DIR/src
	podman build -f images/Dockerfile -t stu-agent .
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
	echo "You should not use $(basename $0) on your home directory"
	usage
	exit 1
fi

if [ -z "$VORTEX_PROJECT_ID" ]; then
	echo "You must set VORTEX_PORJECT_ID envornmnet variable"
	usage
	exit 1
fi

if [ -z "$VORTEX_REGION" ]; then
	echo "You must set VORTEX_REGION envornmnet variable"
	usage
	exit 1
fi


AGENT_ENV=""
AGENT_DEFAULT_ARGS=""
case "${STU_AGENT-}" in
	"claude")
		AGENT_ENV=" -e CLAUDE_CODE_USE_VERTEX=1 \
			    -e CLOUD_ML_REGION=$VORTEX_REGION \
			    -e ANTHROPIC_VERTEX_PROJECT_ID=$VORTEX_PROJECT_ID \
			    -e CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
		AGENT_DEFAULT_ARGS="claude"
	;;
	"opencode")
		AGENT_ENV=" -e GOOGLE_APPLICATION_CREDENTIALS=/home/agent/.config/gcloud/application_default_credentials.json \
			    -e GOOGLE_CLOUD_PROJECT=$VORTEX_PROJECT_ID \
			    -e VERTEX_LOCATION=$VORTEX_REGION"
	;;
esac

podman run -it --rm \
	$AGENT_ENV \
	$GO_CACHE_ARG \
	-v $STU_AGENT_DIR/gcloud:/home/agent/.config/gcloud:ro,z \
	-v $PWD:/workspace:z \
	-w /workspace \
	--userns=keep-id \
	--entrypoint="$STU_AGENT" \
	stu-agent "${@:-$AGENT_DEFAULT_ARGS}"
