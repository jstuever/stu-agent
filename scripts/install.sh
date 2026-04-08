#!/bin/bash

if [ ! -d ~/stu-agent/src ]; then
	mkdir -p ~/stu-agent/src
fi

if [ ! -d ~/stu-agent/src/stu-agent ]; then
	git clone https://github.com/jstuever/stu-agent.git ~/stu-agent/src/stu-agent
fi

if [ ! -d ~/stu-agent/src/ai-helpers ]; then
	git clone https://github.com/openshift-eng/ai-helpers.git ~/stu-agent/src/ai-helpers
fi

if [ -d ~/bin ]; then
	if [ ! -f ~/bin/stu-agent ]; then
		ln -s ~/stu-agent/src/stu-agent/scripts/stu-agent.sh ~/bin/stu-agent
	fi
	if [ ! -f ~/bin/claude-container ]; then
		ln -s ~/stu-agent/src/stu-agent/scripts/claude-container.sh ~/bin/claude-container
	fi
fi
