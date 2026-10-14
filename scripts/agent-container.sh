#!/bin/sh

# Source local config file if it exists
STU_AGENT_DIR="${STU_AGENT_DIR:-$HOME/stu-agent}"
if [ -f "$STU_AGENT_DIR/config" ]; then
	source $STU_AGENT_DIR/config
fi

AI_HELPERS_REPO="${AI_HELPERS:-https://github.com/openshift-eng/ai-helpers.git}"
PULL_SECRET="${PULL_SECRET:-$STU_AGENT_DIR/pull-secret.json}"

# Configure agent
STU_AGENT="${STU_AGENT:-opencode}"
STU_AGENT_PROVIDER="${STU_AGENT_PROVIDER:-vertex}"

# Configure Vertex provider
VERTEX_PROJECT_ID="${VERTEX_PROJECT_ID:-}"
VERTEX_REGION="${VERTEX_REGION:-}"
export CLOUDSDK_CONFIG="$STU_AGENT_DIR/gcloud"

# Configure custom provider
STU_AGENT_PROVIDER_KEY="${STU_AGENT_PROVIDER_KEY:-}"

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
	gcloud init --project "$VERTEX_PROJECT_ID"
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

case "${STU_AGENT_PROVIDER}" in
	"custom")
	;;
	"vertex")
		if [ -z "$VERTEX_PROJECT_ID" ]; then
			echo "You must set VERTEX_PORJECT_ID envornmnet variable"
			usage
			exit 1
		fi

		if [ -z "$VERTEX_REGION" ]; then
			echo "You must set VERTEX_REGION envornmnet variable"
			usage
			exit 1
		fi
	;;
	*)
		echo "Invalid value for STU_AGENT_PROVIDER: ${STU_AGENT_PROVIDER}"
		exit 1
	;;
esac

AGENT_ENV=""
AGENT_DEFAULT_ARGS=""
case "${STU_AGENT-}/${STU_AGENT_PROVIDER-}" in
	"claude/vertex")
		AGENT_ENV=" -e CLAUDE_CODE_USE_VERTEX=1 \
			    -e CLOUD_ML_REGION=$VERTEX_REGION \
			    -e ANTHROPIC_VERTEX_PROJECT_ID=$VERTEX_PROJECT_ID \
			    -e CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
			    -v $STU_AGENT_DIR/gcloud:/home/agent/.config/gcloud:ro,z"
		AGENT_DEFAULT_ARGS="claude"
	;;
	"opencode/vertex")
		AGENT_ENV=" -e GOOGLE_APPLICATION_CREDENTIALS=/home/agent/.config/gcloud/application_default_credentials.json \
			    -e GOOGLE_CLOUD_PROJECT=$VERTEX_PROJECT_ID \
			    -e VERTEX_LOCATION=$VERTEX_REGION \
			    -v $STU_AGENT_DIR/gcloud:/home/agent/.config/gcloud:ro,z"
	;;
	"opencode/custom")
		AGENT_ENV=" -e STU_AGENT_PROVIDER_KEY=$STU_AGENT_PROVIDER_KEY \
		            -v $STU_AGENT_DIR/opencode-custom:/home/agent/.config/opencode:z "
esac

podman run -it --rm \
	$AGENT_ENV \
	$GO_CACHE_ARG \
	-v $PWD:/workspace:z \
	-w /workspace \
	--userns=keep-id:uid=1000,gid=1000 \
	--entrypoint="$STU_AGENT" \
	stu-agent "${@:-$AGENT_DEFAULT_ARGS}"
