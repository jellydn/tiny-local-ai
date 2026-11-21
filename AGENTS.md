# Handbook maintenance

## Scope

Tiny Local AI is a beginner handbook centered on Inkling 2 Mini. README.md contains the guide. This repository does not ship an inference application or training pipeline.

## Writing

- Use clear English and short, direct instructions.
- Define technical terms before using them in beginner instructions.
- Keep local inference, hosted fine-tuning, local training and educational pretraining distinct.
- Distinguish Inkling 2 Mini from Inkling 2 Small.
- Read CONTEXT.md if one is added and applies to the change.

## Sources and claims

- Use official model cards and tool documentation for model and runtime claims.
- Check current sources before changing model IDs, download paths, hardware requirements or compatibility instructions.
- State when a source was checked. Label measurements as measured, source-reported or estimated.
- Keep runtime builds and model formats compatible.
- Link to sybil-solutions/local-ai-registry PR #466 with its full repository name or URL.
- Do not present the drost-ai Small workflow as a verified Mini training recipe.
- Never claim commands or hardware were tested unless they were tested.

## Files and examples

- Keep the repository focused on documentation.
- Keep model weights, downloaded runtimes, credentials and experiment output out of Git.
- Run educational training examples in a separate checkout.
- Run servers, tests and interactive tools in tmux with the current directory name as the session name.
- Ask before destructive operations unless the user has already approved the exact scope.
- Keep commits focused. Do not rewrite history for routine documentation changes.

## Verification

There is no application build or test suite.

Before committing documentation changes:
- Check relative file links and section anchors.
- Check that examples refer to files and external tools that exist.
- Remove references to deleted helpers and dependencies.
- Report which checks ran and which runtime examples were not executed.
