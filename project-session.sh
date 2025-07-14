#!/bin/bash

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Check dependencies
check_dependencies() {
	local missing_deps=()

	command -v tmux >/dev/null 2>&1 || missing_deps+=("tmux")
	command -v nvim >/dev/null 2>&1 || missing_deps+=("nvim")
	command -v fzf >/dev/null 2>&1 || missing_deps+=("fzf")
	command -v rg >/dev/null 2>&1 || missing_deps+=("rg/ripgrep")

	if [[ ${#missing_deps[@]} -gt 0 ]]; then
		echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}" >&2
		echo "Please install the missing dependencies and try again." >&2
		exit 1
	fi
}

# Default directories to ignore (can be overridden with PROJECT_IGNORE_DIRS env var)
get_ignore_patterns() {
	local default_ignores=(
		"node_modules"
		"target"
		"build"
		"dist"
		".git"
		".svn"
		".hg"
		"vendor"
		"__pycache__"
		".pytest_cache"
		".venv"
		"venv"
		".env"
		"coverage"
		".nyc_output"
		".next"
		".nuxt"
		".cache"
		"tmp"
		"temp"
		"logs"
		".DS_Store"
		"Thumbs.db"
		".idea"
		".vscode"
		".vs"
		"bin"
		"obj"
		".gradle"
		".mvn"
		"out"
		".terraform"
	)

	# Use custom ignore list if provided, otherwise use defaults
	if [[ -n "${PROJECT_IGNORE_DIRS:-}" ]]; then
		echo "$PROJECT_IGNORE_DIRS"
	else
		printf "%s\n" "${default_ignores[@]}"
	fi
}

# Check if a directory is a project root (has project indicators)
is_project_root() {
	local dir="$1"
	local indicators=(
		".git"
		".svn"
		".hg"
		"package.json"
		"Cargo.toml"
		"go.mod"
		"pyproject.toml"
		"setup.py"
		"pom.xml"
		"build.gradle"
		"Makefile"
		"CMakeLists.txt"
		"composer.json"
		"Gemfile"
		"mix.exs"
		".project"
		"*.sln"
		"tsconfig.json"
		"deno.json"
		"requirements.txt"
		"Pipfile"
		"yarn.lock"
		"package-lock.json"
		"Dockerfile"
		"docker-compose.yml"
		"README.md"
		"README.rst"
		"README.txt"
		".gitignore"
	)

	for indicator in "${indicators[@]}"; do
		if [[ -e "$dir/$indicator" ]] || ls "$dir"/$indicator >/dev/null 2>&1; then
			return 0
		fi
	done
	return 1
}

# Build ripgrep glob patterns for ignoring directories
build_rg_ignore_globs() {
	local globs=""
	while IFS= read -r ignore_dir; do
		if [[ -n "$ignore_dir" ]]; then
			globs="$globs --glob '!$ignore_dir/' --glob '!**/$ignore_dir/'"
		fi
	done < <(get_ignore_patterns)
	echo "$globs"
}

# Find only actual project roots using ripgrep
find_project_directories() {
	local base_dir="$1"

	# Get ignore globs for ripgrep
	local ignore_globs=$(build_rg_ignore_globs)

	# Find git repositories (primary project indicators)
	local git_repos
	git_repos=$(
		eval "rg --hidden --files --glob '**/.git/config' $ignore_globs '$base_dir' 2>/dev/null" |
			xargs -I {} dirname {} |
			xargs -I {} dirname {} |
			sort -u
	)

	# Build exclusion patterns for areas inside git repos
	local git_excludes=""
	if [[ -n "$git_repos" ]]; then
		while IFS= read -r git_repo; do
			if [[ -n "$git_repo" && "$git_repo" != "$base_dir" ]]; then
				git_excludes="$git_excludes --glob '!${git_repo}/**'"
			fi
		done <<<"$git_repos"
	fi

	# Find other strong project indicators (but only if not in git repos)
	# Focus on primary project files that clearly indicate a project root
	local strong_projects
	strong_projects=$(
		eval "rg --files --type-add 'strongproject:*{package.json,Cargo.toml,go.mod,pyproject.toml,pom.xml,build.gradle,composer.json,Gemfile,mix.exs}' --type strongproject $ignore_globs $git_excludes '$base_dir' 2>/dev/null" |
			xargs -I {} dirname {} |
			sort -u
	)

	# Only return actual project roots
	{
		[[ -n "$git_repos" ]] && echo "$git_repos"
		[[ -n "$strong_projects" ]] && echo "$strong_projects"

		# Only include base directory if it's actually a project
		if is_project_root "$base_dir"; then
			echo "$base_dir"
		fi
	} | sort -u | while IFS= read -r dir; do
		# Only include directories that actually exist and are true project roots
		if [[ -d "$dir" ]] && is_project_root "$dir"; then
			echo "$dir"
		fi
	done
}

# Select project directory using fzf
select_project_directory() {
	local base_dir="$1"

	# Expand tilde in base directory
	base_dir="${base_dir/#\~/$HOME}"

	# Validate base directory
	if [[ ! -d "$base_dir" ]]; then
		echo -e "${RED}Error: Base directory '$base_dir' does not exist${NC}" >&2
		exit 1
	fi

	echo -e "${YELLOW}Searching for project directories in: $base_dir${NC}" >&2

	# Find project directories using ripgrep
	local selected_dir
	selected_dir=$(
		find_project_directories "$base_dir" |
			sed "s|^$base_dir/||" |
			sed "s|^$base_dir$|.|" |
			sort |
			fzf \
				--prompt="Select project directory: " \
				--preview="
                if [[ {} == '.' ]]; then
                    dir_path='$base_dir'
                    echo -e '\033[0;32mBase Directory: $base_dir\033[0m'
                else
                    dir_path='$base_dir/{}'
                    echo -e '\033[0;32mDirectory: $base_dir/{}\033[0m'
                fi
                
                # Show if it's a project root
                if [[ -e \"\$dir_path/.git\" ]] || [[ -e \"\$dir_path/package.json\" ]] || [[ -e \"\$dir_path/Cargo.toml\" ]] || [[ -e \"\$dir_path/go.mod\" ]] || [[ -e \"\$dir_path/pyproject.toml\" ]] || [[ -e \"\$dir_path/setup.py\" ]] || [[ -e \"\$dir_path/pom.xml\" ]] || [[ -e \"\$dir_path/Makefile\" ]]; then
                    echo -e '\033[1;33m[PROJECT ROOT]\033[0m'
                fi
                
                echo 'Contents:'
                ls -la \"\$dir_path\" 2>/dev/null | head -15
            " \
				--preview-window="right:50%" \
				--header="↑/↓: navigate, Enter: select, Esc: cancel" \
				--height=70%
	)

	if [[ -z "$selected_dir" ]]; then
		echo -e "${YELLOW}No directory selected${NC}" >&2
		exit 0
	fi

	# Return the full path
	if [[ "$selected_dir" == "." ]]; then
		echo "$base_dir"
	else
		echo "$base_dir/$selected_dir"
	fi
}

# Create project session
create_project_session() {
	local session_name="$1"
	local project_dir="${2:-$(pwd)}"

	# Check if session already exists
	if tmux has-session -t "$session_name" 2>/dev/null; then
		echo -e "${YELLOW}Session '$session_name' already exists, switching to it${NC}"
		if [[ -n "${TMUX:-}" ]]; then
			tmux switch-client -t "$session_name"
		else
			tmux attach-session -t "$session_name"
		fi
		return
	fi

	# Validate project directory
	if [[ ! -d "$project_dir" ]]; then
		echo -e "${RED}Error: Directory '$project_dir' does not exist${NC}" >&2
		exit 1
	fi

	echo -e "${GREEN}Creating project session: $session_name${NC}"
	echo -e "Working directory: $project_dir"

	# Create new session
	tmux new-session -d -s "$session_name" -c "$project_dir"

	# Split window horizontally (nvim on left, terminal on right)
	tmux split-window -h -t "$session_name" -c "$project_dir"

	# Resize right pane to 25% width
	tmux resize-pane -t "$session_name":1.2 -x 25%

	# Start nvim in the left pane
	tmux send-keys -t "$session_name":1.1 'nvim .' Enter

	# Focus on the nvim pane
	tmux select-pane -t "$session_name":1.1

	# Switch to the session
	if [[ -n "${TMUX:-}" ]]; then
		tmux switch-client -t "$session_name"
	else
		tmux attach-session -t "$session_name"
	fi
}

# Main function
main() {
	check_dependencies

	local session_name=""
	local project_dir=""
	local base_dir=""

	# Parse arguments
	case "${1:-}" in
	-h | --help)
		echo "Usage: $0 [options] [session_name]"
		echo ""
		echo "Create a new tmux project session with nvim and terminal panes"
		echo ""
		echo "Options:"
		echo "  -d, --dir BASE_DIR    Use fzf to select project from directories in BASE_DIR"
		echo "  -h, --help           Show this help message"
		echo ""
		echo "Arguments:"
		echo "  session_name         Name for the tmux session (optional, will prompt if not provided)"
		echo ""
		echo "Environment Variables:"
		echo "  PROJECT_IGNORE_DIRS  Newline-separated list of directory names to ignore"
		echo "                       (overrides default ignore list)"
		echo ""
		echo "Default ignored directories:"
		echo "  node_modules, target, build, dist, .git, .svn, .hg, vendor,"
		echo "  __pycache__, .pytest_cache, .venv, venv, .env, coverage,"
		echo "  .nyc_output, .next, .nuxt, .cache, tmp, temp, logs,"
		echo "  .DS_Store, Thumbs.db, .idea, .vscode, .vs, bin, obj,"
		echo "  .gradle, .mvn, out, .terraform"
		echo ""
		echo "Examples:"
		echo "  $0                              # Prompt for session name, use current directory"
		echo "  $0 myproject                    # Use 'myproject' as session name, current directory"
		echo "  $0 -d ~/code                    # Select project from ~/code using fzf, prompt for session name"
		echo "  $0 -d ~/code myproject          # Select project from ~/code using fzf, use 'myproject' as session name"
		echo "  $0 --dir ~/Documents/projects   # Select project from ~/Documents/projects using fzf"
		echo ""
		echo "  # Custom ignore list:"
		echo "  PROJECT_IGNORE_DIRS=\$'node_modules\\ntarget\\nmy_custom_dir' $0 -d ~/code"
		exit 0
		;;
	-d | --dir)
		if [[ -z "${2:-}" ]]; then
			echo -e "${RED}Error: -d/--dir requires a base directory argument${NC}" >&2
			exit 1
		fi
		base_dir="$2"
		session_name="${3:-}"
		;;
	"")
		# No arguments, prompt for session name
		echo -n "Enter session name: "
		read -r session_name
		project_dir="$(pwd)"
		;;
	*)
		# Single argument is session name
		session_name="$1"
		project_dir="$(pwd)"
		;;
	esac

	# If base_dir is set, use fzf to select project directory
	if [[ -n "$base_dir" ]]; then
		project_dir=$(select_project_directory "$base_dir")

		# If no session name provided, derive it from directory name
		if [[ -z "$session_name" ]]; then
			local dir_name=$(basename "$project_dir")
			session_name="$dir_name"
		fi
	fi

	# Validate session name
	if [[ -z "$session_name" ]]; then
		echo -e "${RED}Error: Session name cannot be empty${NC}" >&2
		exit 1
	fi

	# Expand tilde in project directory if not already done
	if [[ -z "$base_dir" ]]; then
		project_dir="${project_dir/#\~/$HOME}"
	fi

	create_project_session "$session_name" "$project_dir"
}

# Run main function
main "$@"
