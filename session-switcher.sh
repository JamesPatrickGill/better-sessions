#!/bin/bash

set -euo pipefail

# Configuration
PREVIEW_WIDTH="${PREVIEW_WIDTH:-50}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v fzf >/dev/null 2>&1 || missing_deps+=("fzf")
    command -v tmux >/dev/null 2>&1 || missing_deps+=("tmux")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}" >&2
        echo "Please install the missing dependencies and try again." >&2
        exit 1
    fi
}

# Get existing tmux sessions plus option to create new
get_sessions_and_options() {
    echo "➕ Create new session"
    tmux list-sessions 2>/dev/null | cut -d: -f1 || true
}

# Delete session
delete_session() {
    local session_name="$1"
    echo -e "${RED}Deleting session: $session_name${NC}"
    tmux kill-session -t "$session_name"
    echo -e "${GREEN}Session deleted${NC}"
}

# Create new session
create_new_session() {
    echo -n "Enter new session name: "
    read -r session_name
    
    if [[ -z "$session_name" ]]; then
        echo -e "${YELLOW}No session name provided${NC}"
        return 1
    fi
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo -e "${YELLOW}Session '$session_name' already exists${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Creating new session: $session_name${NC}"
    tmux new-session -d -s "$session_name"
    
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
    fi
}

# Switch to session
switch_to_session() {
    local session_name="$1"
    
    echo -e "${GREEN}Switching to session: $session_name${NC}"
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
    fi
}

# Main function
main() {
    check_dependencies
    
    while true; do
        local selection
        selection=$(
            get_sessions_and_options | fzf \
                --prompt="Select session: " \
                --preview="
                    if [[ {} == '➕ Create new session' ]]; then
                        echo -e '\033[0;32mCreate a new tmux session\033[0m'
                        echo 'Press Enter to create a new session'
                    else
                        echo -e '\033[0;32mSession: {}\033[0m'
                        echo 'Windows:'
                        tmux list-windows -t {} -F '  #{window_index}: #{window_name} #{window_flags}' 2>/dev/null || echo '  No windows found'
                    fi
                " \
                --preview-window="right:${PREVIEW_WIDTH}%" \
                --header="Enter: select, Ctrl-D: delete session, Esc: cancel" \
                --bind="ctrl-d:execute(tmux kill-session -t {} 2>/dev/null && echo 'Session {} deleted' || echo 'Could not delete {}')+reload(echo '➕ Create new session'; tmux list-sessions 2>/dev/null | cut -d: -f1 || true)" \
                --height=70%
        )
        
        if [[ -z "$selection" ]]; then
            echo -e "${YELLOW}No selection made${NC}"
            exit 0
        fi
        
        if [[ "$selection" == "➕ Create new session" ]]; then
            create_new_session
            break
        else
            switch_to_session "$selection"
            break
        fi
    done
}

# Run main function
main "$@"