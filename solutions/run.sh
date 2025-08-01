#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 [PUZZLE_NAME] [FLAG]"
    echo "  PUZZLE_NAME: Optional puzzle name (e.g., p23, p14, etc.)"
    echo "  FLAG: Optional flag to pass to puzzle files (e.g., --double-buffer)"
    echo "  If no puzzle specified, runs all puzzles"
    echo "  If no flag specified, runs all detected flags or no flag if none found"
    echo ""
    echo "Examples:"
    echo "  $0                              # Run all puzzles"
    echo "  $0 p23                          # Run only p23 tests with all flags"
    echo "  $0 p26 --double-buffer          # Run p26 with specific flag"
}

run_mojo_files() {
  local path_prefix="$1"
  local specific_flag="$2"

  for f in *.mojo; do
    if [ -f "$f" ] && [ "$f" != "__init__.mojo" ]; then
      # If specific flag is provided, use only that flag
      if [ -n "$specific_flag" ]; then
        # Check if the file supports this flag
        if grep -q "argv()\[1\] == \"$specific_flag\"" "$f" || grep -q "test_type == \"$specific_flag\"" "$f"; then
          echo "=== Running ${path_prefix}$f with flag: $specific_flag ==="
          mojo "$f" "$specific_flag" || echo "Failed: ${path_prefix}$f with $specific_flag"
        else
          echo "Skipping ${path_prefix}$f - does not support flag: $specific_flag"
        fi
      else
        # Original behavior - detect and run all flags or no flag
        flags=$(grep -o 'argv()\[1\] == "--[^"]*"\|test_type == "--[^"]*"' "$f" | cut -d'"' -f2 | grep -v '^--demo')

        if [ -z "$flags" ]; then
          echo "=== Running ${path_prefix}$f ==="
          mojo "$f" || echo "Failed: ${path_prefix}$f"
        else
          for flag in $flags; do
            echo "=== Running ${path_prefix}$f with flag: $flag ==="
            mojo "$f" "$flag" || echo "Failed: ${path_prefix}$f with $flag"
          done
        fi
      fi
    fi
  done
}

run_python_files() {
  local path_prefix="$1"
  local specific_flag="$2"

  for f in *.py; do
    if [ -f "$f" ]; then
      # If specific flag is provided, use only that flag
      if [ -n "$specific_flag" ]; then
        # Check if the file supports this flag
        if grep -q "sys\.argv\[1\] == \"$specific_flag\"" "$f"; then
          echo "=== Running ${path_prefix}$f with flag: $specific_flag ==="
          python "$f" "$specific_flag" || echo "Failed: ${path_prefix}$f with $specific_flag"
        else
          echo "Skipping ${path_prefix}$f - does not support flag: $specific_flag"
        fi
      else
        # Original behavior - detect and run all flags or no flag
        flags=$(grep -o 'sys\.argv\[1\] == "--[^"]*"' "$f" | cut -d'"' -f2 | grep -v '^--demo')

        if [ -z "$flags" ]; then
          echo "=== Running ${path_prefix}$f ==="
          python "$f" || echo "Failed: ${path_prefix}$f"
        else
          for flag in $flags; do
            echo "=== Running ${path_prefix}$f with flag: $flag ==="
            python "$f" "$flag" || echo "Failed: ${path_prefix}$f with $flag"
          done
        fi
      fi
    fi
  done
}

process_directory() {
  local path_prefix="$1"
  local specific_flag="$2"

  run_mojo_files "$path_prefix" "$specific_flag"
  run_python_files "$path_prefix" "$specific_flag"
}

# Parse command line arguments
SPECIFIC_PUZZLE=""
SPECIFIC_FLAG=""
if [ $# -eq 1 ]; then
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi
    SPECIFIC_PUZZLE="$1"
elif [ $# -eq 2 ]; then
    SPECIFIC_PUZZLE="$1"
    SPECIFIC_FLAG="$2"
elif [ $# -gt 2 ]; then
    echo "Error: Too many arguments"
    usage
    exit 1
fi

cd solutions || exit 1

# Function to test a specific directory
test_puzzle_directory() {
    local dir="$1"
    local specific_flag="$2"

    if [ -n "$specific_flag" ]; then
        echo "=== Testing solutions in ${dir} with flag: $specific_flag ==="
    else
        echo "=== Testing solutions in ${dir} ==="
    fi

    cd "$dir" || return 1

    process_directory "${dir}" "$specific_flag"

    # Check for test directory and run mojo test (only if no specific flag)
    if [ -z "$specific_flag" ] && ([ -d "test" ] || [ -d "tests" ]); then
        echo "=== Running tests in ${dir} ==="
        mojo test . || echo "Failed: mojo test in ${dir}"
    fi

    cd ..
}

if [ -n "$SPECIFIC_PUZZLE" ]; then
    # Run specific puzzle
    if [ -d "${SPECIFIC_PUZZLE}/" ]; then
        test_puzzle_directory "${SPECIFIC_PUZZLE}/" "$SPECIFIC_FLAG"
    else
        echo "Error: Puzzle directory '${SPECIFIC_PUZZLE}' not found"
        echo "Available puzzles:"
        ls -d p*/ 2>/dev/null | tr -d '/' | sort
        exit 1
    fi
else
    # Run all puzzles (original behavior)
    for dir in p*/; do
        if [ -d "$dir" ]; then
            test_puzzle_directory "$dir" "$SPECIFIC_FLAG"
        fi
    done
fi

cd ..
