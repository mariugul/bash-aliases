#!/bin/bash
# Color Utilities
# Simple color helper functions for terminal output
#
# Usage Examples:
#   text "Error message"                         # Plain text
#   text "Error message" red                     # Red bold text (default format)
#   text "Success!" green                        # Green text without formatting
#   text "Info" blue bold                        # Blue bold text
#   text "Warning" yellow italic                 # Yellow italic text
#   text "Alert" red bold,italic                 # Red bold italic text
#   text "Important" purple bold,underline       # Purple bold underlined text
#   text "Emphasis" cyan italic,underline        # Cyan italic underlined text
#   text "All formats" green bold,italic,underline # Green bold italic underlined text
#   text "Bold only" bold                        # Bold text without color
#   text "Multiple formats" bold,italic          # Bold italic text without color

# Enhanced text styling function (colors and formatting)
text() {
    local text="$1"
    local color="$2"    # Optional: red, green, yellow, blue, purple, cyan, white
    shift 2 2>/dev/null || shift $# # Remove first two args, or all if less than 2
    local formats="$*"  # All remaining arguments as formatting options
    
    # If no arguments provided, just return
    if [[ -z "$text" ]]; then
        return
    fi
    
    # If only text provided, output plain text
    if [[ -z "$color" ]]; then
        echo "$text"
        return
    fi
    
    local color_code=""
    local format_codes=()
    
    # Check if second argument is actually a format, not a color
    case "$color" in
        bold|italic|underline|*,*)
            # Second argument is formatting, not color
            formats="$color $formats"
            color=""
            ;;
        red)     color_code="31" ;;
        green)   color_code="32" ;;
        yellow)  color_code="33" ;;
        blue)    color_code="34" ;;
        purple)  color_code="35" ;;
        cyan)    color_code="36" ;;
        white)   color_code="37" ;;
        *)       
            # Unknown color, treat as plain text
            echo "$text"
            return
            ;;
    esac
    
    # Parse formatting options (can be comma-separated or space-separated)
    local format_string=""
    if [[ -n "$formats" ]]; then
        # Replace commas with spaces and process each format
        formats="${formats//,/ }"
        for format in $formats; do
            case "$format" in
                bold)      format_codes+=("1") ;;
                italic)    format_codes+=("3") ;;
                underline) format_codes+=("4") ;;
            esac
        done
    fi
    
    # Build the escape sequence
    local escape_seq="\033["
    local codes=()
    
    # Add format codes
    if [[ ${#format_codes[@]} -gt 0 ]]; then
        codes+=("${format_codes[@]}")
    elif [[ -n "$color_code" ]]; then
        # Default to bold if color is specified but no format
        codes+=("1")
    fi
    
    # Add color code
    if [[ -n "$color_code" ]]; then
        codes+=("$color_code")
    fi
    
    # Join codes with semicolons
    if [[ ${#codes[@]} -gt 0 ]]; then
        local IFS=";"
        escape_seq="${escape_seq}${codes[*]}m"
        echo -e "${escape_seq}${text}\033[00m"
    else
        echo "$text"
    fi
}

# Dedicated formatting functions for convenience
bold() {
    echo -e "\033[1m$1\033[00m"
}

italic() {
    echo -e "\033[3m$1\033[00m"
}

underline() {
    echo -e "\033[4m$1\033[00m"
}

# Backward compatibility alias
color() {
    text "$@"
}
