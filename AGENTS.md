# AGENTS.md

This project contains configuration files for various development tools.

## Build/Lint/Test

- There are no project-wide build, lint, or test commands.
- Configuration is managed by setup scripts in each tool's directory (e.g., `zsh/setup.sh`, `neovim/setup.sh`).
- When modifying a tool's configuration, refer to its specific documentation and `README.md` for validation steps.

## Code Style

- Adhere to the `.editorconfig` file for formatting.
- **Lua**: Use 4-space indentation for `.lua` files.
- **Shell**: Use 2-space indentation for `.sh` and `.zsh` files.
- **Naming**: Follow existing naming conventions in the respective configuration files.
- **Error Handling**: Ensure scripts and configurations are robust and handle potential errors gracefully.
- No specific import, typing, or error handling conventions are defined project-wide. Follow the conventions of the file you are editing.
