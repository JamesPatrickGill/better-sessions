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

# Select project directory using fzf with rg
select_project_directory() {
	local base_dir="$1"

	# Expand tilde in base directory
	base_dir="${base_dir/#\~/$HOME}"

	# Validate base directory
	if [[ ! -d "$base_dir" ]]; then
		echo -e "${RED}Error: Base directory '$base_dir' does not exist${NC}" >&2
		exit 1
	fi

	echo -e "${YELLOW}Browsing directories in: $base_dir${NC}" >&2

	# Use rg to find .git directories, extract their parent directories
	local selected_dir
	selected_dir=$(
		rg --files --hidden --glob "**/.git/config" "$base_dir" 2>/dev/null | \
		xargs -I {} dirname {} | \
		xargs -I {} dirname {} | \
		sort -u | \
		fzf \
			--prompt="Select git repository: " \
			--preview="
				echo -e '\033[0;34m{}\033[0m'
				echo
				if cd {} 2>/dev/null; then
					echo -e '\033[0;32mGit Status:\033[0m'
					git status --porcelain 2>/dev/null | head -5 || echo 'Clean working directory'
					echo
					echo -e '\033[0;32mRecent Commits:\033[0m'
					git log --oneline -5 2>/dev/null || echo 'No commits'
					echo
					echo -e '\033[0;32mBranches:\033[0m'
					git branch 2>/dev/null || echo 'No branches'
				else
					echo 'Cannot access directory'
				fi
			" \
			--preview-window="right:50%" \
			--height=70%
	)

	if [[ -z "$selected_dir" ]]; then
		echo -e "${YELLOW}No directory selected${NC}" >&2
		exit 0
	fi

	echo "$selected_dir"
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
		echo "  -d, --dir BASE_DIR    Browse directories in BASE_DIR with fzf"
		echo "  -h, --help           Show this help message"
		echo ""
		echo "Arguments:"
		echo "  session_name         Name for the tmux session (optional, will use directory name)"
		echo ""
		echo "Examples:"
		echo "  $0                              # Use current directory"
		echo "  $0 myproject                    # Use current directory with session name 'myproject'"
		echo "  $0 -d ~/code                    # Browse and select from ~/code"
		echo "  $0 -d ~/code myproject          # Browse ~/code, use 'myproject' as session name"
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
		# No arguments, use current directory
		project_dir="$(pwd)"
		session_name=$(basename "$project_dir")
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

		# If no session name provided, use directory name
		if [[ -z "$session_name" ]]; then
			session_name=$(basename "$project_dir")
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
