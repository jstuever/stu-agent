#!/bin/bash

# aggregate_usage.sh - Aggregate cost and token usage from Claude Code log files
# Usage: cat logs/*.log | ./aggregate_usage.sh
#    or: ./aggregate_usage.sh < logs/*.log

set -euo pipefail

# Initialize counters
total_cost=0
input_tokens=0
output_tokens=0
cache_creation_tokens=0
cache_read_tokens=0
reasoning_tokens=0
tool_uses=0

# Track unique sessions
declare -A seen_sessions
sessions=0

# Read stdin line by line
while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Check if line is valid JSON
    if echo "$line" | jq -e . >/dev/null 2>&1; then
        # claude - Extract total_cost_usd if present (from result lines)
        cost=$(echo "$line" | jq -r '.total_cost_usd // empty' 2>/dev/null || true)
        if [[ -n "$cost" ]]; then
            total_cost=$(echo "$total_cost + $cost" | bc)
        fi

        # opencode - Extract part.cost if present (from result lines)
        cost=$(echo "$line" | jq -r '.part.cost // empty' 2>/dev/null || true)
        if [[ -n "$cost" ]]; then
            total_cost=$(echo "$total_cost + $cost" | bc)
        fi

        # claude - Extract session_id for counting unique sessions
        session_id=$(echo "$line" | jq -r '.session_id // empty' 2>/dev/null || true)
        if [[ -n "$session_id" ]] && [[ -z "${seen_sessions[$session_id]:-}" ]]; then
            seen_sessions[$session_id]=1
            ((sessions++)) || true
        fi

        # opencode - Extract sessionID for counting unique sessions
        session_id=$(echo "$line" | jq -r '.sessionID // empty' 2>/dev/null || true)
        if [[ -n "$session_id" ]] && [[ -z "${seen_sessions[$session_id]:-}" ]]; then
            seen_sessions[$session_id]=1
            ((sessions++)) || true
        fi

	# claude - Extract usage.input_tokens
        usage_input=$(echo "$line" | jq -r '.usage.input_tokens // empty' 2>/dev/null || true)
        if [[ -n "$usage_input" ]]; then
            input_tokens=$((input_tokens + usage_input))
        fi

	# opencode - Extract part.tokens.input
        usage_input=$(echo "$line" | jq -r '.part.tokens.input // empty' 2>/dev/null || true)
        if [[ -n "$usage_input" ]]; then
            input_tokens=$((input_tokens + usage_input))
        fi

	# claude - Extract usage.output_tokens
        usage_output=$(echo "$line" | jq -r '.usage.output_tokens // empty' 2>/dev/null || true)
        if [[ -n "$usage_output" ]]; then
            output_tokens=$((output_tokens + usage_output))
        fi

	# opencode - Extract part.tokens.output
        usage_output=$(echo "$line" | jq -r '.part.tokens.output // empty' 2>/dev/null || true)
        if [[ -n "$usage_output" ]]; then
            output_tokens=$((output_tokens + usage_output))
        fi

	# claude - Extract usage.cache_create_tokens
        usage_cache_create=$(echo "$line" | jq -r '.usage.cache_creation_input_tokens // empty' 2>/dev/null || true)
        if [[ -n "$usage_cache_create" ]]; then
            cache_creation_tokens=$((cache_creation_tokens + usage_cache_create))
        fi

	# opencode - Extract part.tokens.cache.write
        usage_cache_create=$(echo "$line" | jq -r '.part.tokens.cache.write // empty' 2>/dev/null || true)
        if [[ -n "$usage_cache_create" ]]; then
            cache_creation_tokens=$((cache_creation_tokens + usage_cache_create))
        fi

	# claude - Extract usage.cache_read_input_tokens
        usage_cache_read=$(echo "$line" | jq -r '.usage.cache_read_input_tokens // empty' 2>/dev/null || true)
        if [[ -n "$usage_cache_read" ]]; then
            cache_read_tokens=$((cache_read_tokens + usage_cache_read))
        fi

	# opencode - Extract part.tokens.cache.read
        usage_cache_read=$(echo "$line" | jq -r '.part.tokens.cache.read // empty' 2>/dev/null || true)
        if [[ -n "$usage_cache_read" ]]; then
            cache_read_tokens=$((cache_read_tokens + usage_cache_read))
        fi

	# opencode - Extract part.tokens.reasoning
        usage_reasoning=$(echo "$line" | jq -r '.part.tokens.reasoning // empty' 2>/dev/null || true)
        if [[ -n "$usage_reasoning" ]]; then
            reasoning_tokens=$((reasoning_tokens + usage_reasoning ))
        fi

        usage_tools=$(echo "$line" | jq -r '.usage.tool_uses // empty' 2>/dev/null || true)
        if [[ -n "$usage_tools" ]]; then
            tool_uses=$((tool_uses + usage_tools))
        fi
    fi
done

# Format cost to 2 decimal places
formatted_cost=$(printf "%.2f" "$total_cost")
sum_tokens=$((input_tokens + output_tokens + reasoning_tokens + cache_creation_tokens + cache_read_tokens))

# Output summary
echo "================================"
echo "Claude Code Usage Summary"
echo "================================"
echo ""
echo "Sessions:              $sessions"
echo ""
echo "Cost:                  \$$formatted_cost"
echo ""
echo "Token Usage:           $(printf "%'d" $sum_tokens)"
echo "  Input tokens:        $(printf "%'d" $input_tokens)"
echo "  Output tokens:       $(printf "%'d" $output_tokens)"
echo "  Reasoning tokens:    $(printf "%'d" $reasoning_tokens)"
echo "  Cache creation:      $(printf "%'d" $cache_creation_tokens)"
echo "  Cache read:          $(printf "%'d" $cache_read_tokens)"
echo ""
echo "Tool uses:             $tool_uses"
echo ""
