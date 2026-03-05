#!/usr/bin/env zsh

# Zsh completion for ./swap command
# Install with: 
#   mkdir -p ~/.zsh/completions
#   ln -s /path/to/swap-completion.zsh ~/.zsh/completions/_swap
#   Add to ~/.zshrc: fpath=(~/.zsh/completions $fpath)

_swap() {
	local -a commands=('status:Show current model and server status'
		'qwen:Switch to Qwen3-Coder-Next model'
		'glm:Switch to GLM-4.7-Flash model'
		'start:Start the server'
		'stop:Stop the server'
		'help:Show help message')

	local -a global_flags=('--wait:Custom timeout for server startup'
		'--verbose:Show detailed output'
		'--help:Show help message')

	local state

	_arguments \
		'1: :->commands' \
		'*::->args'

	case $state in
	commands)
		_describe 'command' commands
		;;
	args)
		case $words[2] in
		qwen | glm)
			_arguments \
				'--wait[Custom timeout for server startup]:timeout:' \
				'--verbose[Show detailed output]' \
				'--help[Show help message]'
			;;
		start | stop | status | help)
			_arguments \
				'--verbose[Show detailed output]' \
				'--help[Show help message]'
			;;
		esac
		;;
	esac
}

_swap "$@"
