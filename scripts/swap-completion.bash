#!/usr/bin/env bash

# Bash completion for ./swap command
# Install with: complete -o bashdefault -o default -o nospace -F _swap_completion swap

_swap_completion() {
	local cur prev words cword
	cur="${COMP_WORDS[cword]}"
	prev="${COMP_WORDS[cword - 1]}"
	words=("${COMP_WORDS[@]}")
	cword=${COMP_CWORD}

	# Main commands
	local commands="status qwen glm start stop help"

	case "$prev" in
	swap | ./swap)
		COMPREPLY=($(compgen -W "$commands" -- "$cur"))
		return 0
		;;
	esac

	# Flags for swap command
	case "$cur" in
	--*)
		local flags="--wait --verbose --help"
		COMPREPLY=($(compgen -W "$flags" -- "$cur"))
		return 0
		;;
	esac

	# Default: show available commands
	if [[ $cword -eq 1 ]]; then
		COMPREPLY=($(compgen -W "$commands" -- "$cur"))
	fi
}

complete -o bashdefault -o default -o nospace -F _swap_completion swap
