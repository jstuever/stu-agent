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
        # Extract total_cost_usd if present (from result lines)
        cost=$(echo "$line" | jq -r '.total_cost_usd // empty' 2>/dev/null || true)
        if [[ -n "$cost" ]]; then
            total_cost=$(echo "$total_cost + $cost" | bc)
        fi

        # Extract session_id for counting unique sessions
        session_id=$(echo "$line" | jq -r '.session_id // empty' 2>/dev/null || true)
        if [[ -n "$session_id" ]] && [[ -z "${seen_sessions[$session_id]:-}" ]]; then
            seen_sessions[$session_id]=1
            ((sessions++)) || true
        fi

        usage_input=$(echo "$line" | jq -r '.usage.input_tokens // empty' 2>/dev/null || true)
        if [[ -n "$usage_input" ]]; then
            input_tokens=$((input_tokens + usage_input))
        fi

        usage_output=$(echo "$line" | jq -r '.usage.output_tokens // empty' 2>/dev/null || true)
        if [[ -n "$usage_output" ]]; then
            output_tokens=$((output_tokens + usage_output))
        fi

        usage_cache_create=$(echo "$line" | jq -r '.usage.cache_creation_input_tokens // empty' 2>/dev/null || true)
        if [[ -n "$usage_cache_create" ]]; then
            cache_creation_tokens=$((cache_creation_tokens + usage_cache_create))
        fi

        usage_cache_read=$(echo "$line" | jq -r '.usage.cache_read_input_tokens // empty' 2>/dev/null || true)
        if [[ -n "$usage_cache_read" ]]; then
            cache_read_tokens=$((cache_read_tokens + usage_cache_read))
        fi

        usage_tools=$(echo "$line" | jq -r '.usage.tool_uses // empty' 2>/dev/null || true)
        if [[ -n "$usage_tools" ]]; then
            tool_uses=$((tool_uses + usage_tools))
        fi
    fi
done

# Format cost to 2 decimal places
formatted_cost=$(printf "%.2f" "$total_cost")
sum_tokens=$((input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens))

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
echo "  Cache creation:      $(printf "%'d" $cache_creation_tokens)"
echo "  Cache read:          $(printf "%'d" $cache_read_tokens)"
echo ""
echo "Tool uses:             $tool_uses"
echo ""
