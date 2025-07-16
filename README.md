# Better Sessions

A collection of bash scripts for enhanced tmux session management, optimized for my personal development workflow.

## ⚠️ Personal Use Notice

These scripts are **heavily optimized for my specific setup and preferences**. They work great for me, but they might not work for you out of the box. If you like the concepts but the implementation doesn't fit your workflow, I encourage you to fork this and make your own version!

## What This Does

### `session-switcher.sh`

An interactive tmux session manager with fzf integration:

- 📋 Lists all existing tmux sessions with preview
- ➕ Create new sessions from the menu
- 🗑️ Delete sessions with `Ctrl-D` hotkey
- 🔄 Live reload after operations
- 👁️ Rich previews showing session windows and details

### `project-session.sh`

A smart project session creator:

- 📁 Browse project directories with fzf
- 🚀 Automatically creates tmux sessions with nvim + terminal layout
- 🛑 Respects git repository boundaries (stops at `.git`)
- ⚡ Fast directory discovery using ripgrep
- 🙈 Ignores common build/dependency directories
- 🎯 Only shows actual project roots, not random subdirectories

## Dependencies

You'll need these tools installed:

```bash
# Core tools
tmux       # Session management
fzf        # Fuzzy finder interface
rg         # Ripgrep for fast file searching
nvim       # Neovim (or change to your preferred editor)
```

## Installation

```bash
# Clone or download the scripts
git clone <your-repo> better-sessions
cd better-sessions

# Make them executable
chmod +x session-switcher.sh project-session.sh

# Optional: Add to your PATH or create aliases
echo 'alias s="~/path/to/session-switcher.sh"' >> ~/.bashrc
echo 'alias p="~/path/to/project-session.sh -d ~/code"' >> ~/.bashrc
```

## Usage

### Command Line
```bash
# Session switcher - Interactive session management
./session-switcher.sh

# Project session creator - Browse git repositories
./project-session.sh -d ~/code

# Use current directory
./project-session.sh myproject

# Show help
./project-session.sh --help
```

### tmux Hotkeys (Recommended)
Add these bindings to your `~/.config/tmux/tmux.conf`:

```bash
# Project session creator - browse git repos and create sessions
bind-key o display-popup -E -w 80% -h 70% "~/path/to/better-sessions/project-session.sh -d ~/code"

# Session switcher - manage existing sessions  
bind-key O display-popup -E -w 80% -h 70% "~/path/to/better-sessions/session-switcher.sh"
```

Then reload tmux config: `tmux source-file ~/.config/tmux/tmux.conf`

**Hotkeys:**
- **`Ctrl-Space + o`** (lowercase) → Project creator popup (browse git repos)
- **`Ctrl-Space + O`** (uppercase) → Session switcher popup (manage sessions)

### Navigation
```bash
# Session Switcher:
# ↑/↓: Navigate sessions
# Enter: Switch to session  
# Ctrl-D: Delete session
# Esc: Cancel

# Project Creator:
# ↑/↓: Navigate git repositories
# Enter: Create session with repo name
# Esc: Cancel
# Preview shows: git status, recent commits, branches
```

## Layout Created

When you create a project session, you get:

```
┌─────────────────────────────┬─────────┐
│                             │         │
│          nvim .             │terminal │
│         (75%)               │  (25%)  │
│                             │         │
└─────────────────────────────┴─────────┘
```

## Personal Quirks & Optimizations

### tmux Index Settings

My tmux is configured with **1-based indexing** for windows and panes:

```tmux
# In ~/.tmux.conf
set -g base-index 1
setw -g pane-base-index 1
```

If you use 0-based indexing (default), you'll need to change the pane targeting in `project-session.sh` from `:1.1` and `:1.2` to `:0.0` and `:0.1`.

### Directory Structure Assumptions

The scripts assume a typical code directory structure like:

```
~/code/
├── project1/          # Git repo
├── project2/          # Has package.json
├── project3/          # Has Cargo.toml
└── random-folder/     # Not a project, ignored
```

### Ignored Directories

I work primarily with Node.js, Rust, and Go projects, so the ignore list reflects that:

```bash
node_modules, target, build, dist, .git, vendor, __pycache__,
.venv, .next, .cache, .idea, .vscode, bin, obj, etc.
```

### Customization

You can override the ignore list:

```bash
export PROJECT_IGNORE_DIRS=$'node_modules\ntarget\nmy_custom_dir'
./project-session.sh -d ~/code
```

## Why These Choices?

- **fzf**: Because interactive selection beats typing paths
- **ripgrep**: Blazingly fast, even on huge codebases  
- **Git repositories only**: No clutter, only actual projects
- **tmux popups**: Access from anywhere without finding a terminal
- **Git previews**: See repo status before switching
- **Nvim + terminal**: My preferred dev layout (75% editor, 25% terminal)

## Making It Yours

If you want to adapt this:

1. **Change the editor**: Replace `nvim .` with `code .`, `vim .`, etc.
2. **Adjust layout**: Modify the tmux split and resize commands
3. **Different ignore patterns**: Update the `get_ignore_patterns` function
4. **Project detection**: Modify `is_project_root` for your project types
5. **tmux indexing**: Adjust pane targeting if you use 0-based indexing

## Contributing

This is a personal tool, but if you find bugs or have suggestions that align with the general workflow, feel free to open an issue. Just remember - if it works for me but not for you, that's probably by design!

## License

Do whatever you want with this code. If it helps you, great! If not, make your own version that works better for your setup.
