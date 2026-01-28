#!/bin/bash
#
# check-verbose-logging.sh
#
# Checks that all logging statements in library code are guarded by verbose mode.
# This prevents debug output from being printed in production builds.
#
# Exit codes:
#   0 - All logging is properly guarded
#   1 - Found unconditional logging statements
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Get the root directory (parent of makefiles/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

found_issues=0
issues=""

# Function to add an issue
add_issue() {
    local file="$1"
    local line="$2"
    local content="$3"
    issues="$issues\n  ${file}:${line}: ${content}"
    found_issues=1
}

# ============================================================================
# Check Kotlin files for unconditional Log.d/e/w/i/v calls
# ============================================================================
check_kotlin() {
    local android_src="$ROOT_DIR/pro_video_player_android/android/src/main/kotlin"

    if [ ! -d "$android_src" ]; then
        return
    fi

    # Find all Kotlin files, excluding test directories
    while IFS= read -r -d '' file; do
        # Skip if file doesn't exist
        [ -f "$file" ] || continue

        # Read file and check each line
        local line_num=0
        while IFS= read -r line || [ -n "$line" ]; do
            line_num=$((line_num + 1))

            # Skip comments
            if [[ "$line" =~ ^[[:space:]]*(//|\*|/\*) ]]; then
                continue
            fi

            # Check for Log.d/e/w/i/v calls
            if [[ "$line" =~ Log\.[dewiv]\( ]]; then
                # Allow if inside verboseLog function definition (ProVideoPlayerPlugin.kt)
                if [[ "$file" == *"ProVideoPlayerPlugin.kt" ]] && [[ "$line" =~ android\.util\.Log\.d ]]; then
                    # This is the verboseLog implementation - allowed
                    continue
                fi

                # Allow MediaRouteButtonView.kt - Cast dialog logging is required for debugging
                # cast connectivity issues which are notoriously difficult to diagnose
                if [[ "$file" == *"MediaRouteButtonView.kt" ]]; then
                    continue
                fi

                # This is an unconditional log call
                local relative_file="${file#$ROOT_DIR/}"
                local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-60)
                add_issue "$relative_file" "$line_num" "$trimmed_line"
            fi
        done < "$file"
    done < <(find "$android_src" -name "*.kt" -type f -print0 2>/dev/null)
}

# ============================================================================
# Check Swift files for unconditional print/NSLog calls
# ============================================================================
check_swift() {
    local swift_src="$ROOT_DIR/shared_apple_sources"

    if [ ! -d "$swift_src" ]; then
        return
    fi

    while IFS= read -r -d '' file; do
        [ -f "$file" ] || continue

        # Skip VerboseLogger.swift - it's the logger implementation
        if [[ "$file" == *"VerboseLogger.swift" ]]; then
            continue
        fi

        local line_num=0
        while IFS= read -r line || [ -n "$line" ]; do
            line_num=$((line_num + 1))

            # Skip comments
            if [[ "$line" =~ ^[[:space:]]*(//|\*|/\*) ]]; then
                continue
            fi

            # Check for print( or NSLog( calls
            if [[ "$line" =~ print\( ]] || [[ "$line" =~ NSLog\( ]]; then
                local relative_file="${file#$ROOT_DIR/}"
                local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-60)
                add_issue "$relative_file" "$line_num" "$trimmed_line"
            fi
        done < "$file"
    done < <(find "$swift_src" -name "*.swift" -type f -print0 2>/dev/null)
}

# ============================================================================
# Check Dart lib files for unconditional print/debugPrint calls
# ============================================================================
check_dart() {
    local packages=(
        "pro_video_player/lib"
        "pro_video_player_platform_interface/lib"
        "pro_video_player_android/lib"
        "pro_video_player_ios/lib"
        "pro_video_player_macos/lib"
        "pro_video_player_web/lib"
    )

    for pkg_lib in "${packages[@]}"; do
        local lib_dir="$ROOT_DIR/$pkg_lib"

        if [ ! -d "$lib_dir" ]; then
            continue
        fi

        while IFS= read -r -d '' file; do
            [ -f "$file" ] || continue

            # Skip logger files - they're the implementation
            if [[ "$file" == *"logger.dart" ]] || [[ "$file" == *"verbose_logging.dart" ]]; then
                continue
            fi

            local line_num=0
            local in_doc_comment=0
            while IFS= read -r line || [ -n "$line" ]; do
                line_num=$((line_num + 1))

                # Track doc comments (/// or /** */)
                if [[ "$line" =~ ^[[:space:]]*/// ]]; then
                    continue  # Skip dartdoc lines
                fi

                # Skip regular comments
                if [[ "$line" =~ ^[[:space:]]*(//|\*|/\*) ]]; then
                    continue
                fi

                # Check for print( or debugPrint( calls (but not in strings)
                # Simple heuristic: if line has print( not preceded by ' or "
                if [[ "$line" =~ [^\'\"[:alnum:]]print\( ]] || [[ "$line" =~ ^print\( ]]; then
                    local relative_file="${file#$ROOT_DIR/}"
                    local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-60)
                    add_issue "$relative_file" "$line_num" "$trimmed_line"
                fi

                if [[ "$line" =~ [^\'\"[:alnum:]]debugPrint\( ]] || [[ "$line" =~ ^debugPrint\( ]]; then
                    local relative_file="${file#$ROOT_DIR/}"
                    local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-60)
                    add_issue "$relative_file" "$line_num" "$trimmed_line"
                fi
            done < "$file"
        done < <(find "$lib_dir" -name "*.dart" -type f -print0 2>/dev/null)
    done
}

# ============================================================================
# Check Web files for unconditional console.log calls
# ============================================================================
check_web() {
    local web_lib="$ROOT_DIR/pro_video_player_web/lib"

    if [ ! -d "$web_lib" ]; then
        return
    fi

    while IFS= read -r -d '' file; do
        [ -f "$file" ] || continue

        # Skip verbose_logging.dart - it's the logger implementation
        if [[ "$file" == *"verbose_logging.dart" ]]; then
            continue
        fi

        local line_num=0
        while IFS= read -r line || [ -n "$line" ]; do
            line_num=$((line_num + 1))

            # Skip comments
            if [[ "$line" =~ ^[[:space:]]*(//|\*|/\*|///) ]]; then
                continue
            fi

            # Check for console.log/warn/error/info/debug calls
            if [[ "$line" =~ console\.(log|warn|error|info|debug)\( ]]; then
                local relative_file="${file#$ROOT_DIR/}"
                local trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-60)
                add_issue "$relative_file" "$line_num" "$trimmed_line"
            fi
        done < "$file"
    done < <(find "$web_lib" -name "*.dart" -type f -print0 2>/dev/null)
}

# ============================================================================
# Main
# ============================================================================

# Run all checks
check_kotlin
check_swift
check_dart
check_web

# Report results
if [ $found_issues -eq 1 ]; then
    echo -e "${RED}Found unconditional logging statements:${NC}"
    echo -e "$issues"
    echo ""
    echo "All logging in library code must use verbose logging functions:"
    echo "  - Kotlin: ProVideoPlayerPlugin.verboseLog(message, tag)"
    echo "  - Swift:  verboseLog(message, tag:)"
    echo "  - Dart:   ProVideoPlayerLogger.log(message, tag:)"
    echo "  - Web:    verboseLog(message, tag:)"
    exit 1
else
    echo -e "${GREEN}All logging is properly guarded by verbose mode${NC}"
    exit 0
fi
