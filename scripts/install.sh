#!/bin/bash

if [ ! -d ~/stu-agent ]; then
	mkdir -p ~/stu-agent
fi

if [ ! -d ~/stu-agent/src ]; then
	git clone https://github.com/jstuever/stu-agent.git ~/stu-agent/src
fi

if [ -d ~/bin ]; then
	if [ ! -f ~/bin/stu-agent ]; then
		ln -s ~/stu-agent/src/scripts/stu-agent.sh ~/bin/stu-agent
	fi
	if [ ! -f ~/bin/agent-container ]; then
		ln -s ~/stu-agent/src/scripts/claude-container.sh ~/bin/agent-container
	fi
	if [ ! -f ~/bin/aggregate_claude_usage.sh ]; then
		ln -s ~/stu-agent/src/scripts/aggregate_claude_usage.sh ~/bin/aggregate_claude_usage
	fi
fi
