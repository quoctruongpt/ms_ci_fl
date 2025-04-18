#!/bin/bash

# Script to reset local changes, pull latest, update version, create git tag, generate changelog, commit changelog, and push for the Flutter project inside src/flutter_project
# WARNING: This script performs 'git reset --hard HEAD' and 'git clean -fdx' which DISCARDS ALL LOCAL UNCOMMITTED CHANGES AND UNTRACKED FILES. Use with extreme caution!
# Usage: ./ci/scripts/generate_flutter_changelog.sh <new_version> [branch_name]
# Example: ./ci/scripts/generate_flutter_changelog.sh 1.2.3 develop
# If branch_name is omitted, it defaults to 'main'.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
FLUTTER_PROJECT_DIR="src/flutter_project"
PUBSPEC_FILE="pubspec.yaml"
CHANGELOG_FILE="CHANGELOG.md"
GIT_TAG_PREFIX="v" # e.g., v1.2.3
VERSION_COMMIT_MESSAGE_PREFIX="chore(release): set version to"
CHANGELOG_COMMIT_MESSAGE_PREFIX="docs(changelog): update changelog for"
# Set default remote name
GIT_REMOTE_NAME="origin"

# --- Argument Handling ---
NEW_VERSION=$1
TARGET_BRANCH=$2 # Optional branch name
if [ -z "$NEW_VERSION" ]; then
  echo "Error: New version argument is required."
  echo "Usage: $0 <new_version> [branch_name]"
  exit 1
fi
echo "Preparing to set version to: $NEW_VERSION"

# --- Prerequisite Checks ---

# Function to check and install conventional-changelog-cli globally
check_and_install_global_pkg() {
  local pkg_cmd="conventional-changelog"
  local npm_pkg="conventional-changelog-cli"

  echo "Checking for global command: $pkg_cmd..."
  if ! command -v "$pkg_cmd" &> /dev/null; then
    echo "'$pkg_cmd' command not found globally."
    echo "Checking for npm..."
    if ! command -v npm &> /dev/null; then
        echo "Error: npm is required to install '$npm_pkg' globally, but npm command was not found."
        exit 1
    fi
    echo "Attempting to install '$npm_pkg' globally using npm..."
    # IMPORTANT: This might require sudo depending on your npm configuration.
    if npm install -g "$npm_pkg"; then
        echo "'$npm_pkg' installed globally successfully."
        hash -r 2>/dev/null || true # Refresh command cache
        if ! command -v "$pkg_cmd" &> /dev/null; then
           echo "Error: Installation seemed successful, but '$pkg_cmd' command is still not found. Check your PATH or npm global setup."
           exit 1
        fi
    else
        echo "Error: Failed to install '$npm_pkg' globally. You might need to run 'npm install -g $npm_pkg' manually (possibly with sudo)."
        exit 1
    fi
  else
    echo "'$pkg_cmd' is already installed globally."
  fi
}

# Run the check and install function for conventional-changelog
check_and_install_global_pkg

# --- Script Execution ---

# Store the original directory
ORIGINAL_DIR=$(pwd)

# Check if the Flutter project directory exists
if [ ! -d "$FLUTTER_PROJECT_DIR" ]; then
  echo "Error: Flutter project directory '$FLUTTER_PROJECT_DIR' not found."
  exit 1
fi

# Navigate into the Flutter project directory
echo "Changing directory to $FLUTTER_PROJECT_DIR..."
cd "$FLUTTER_PROJECT_DIR" || exit 1

# Check if it's a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: '$FLUTTER_PROJECT_DIR' is not a Git repository."
  cd "$ORIGINAL_DIR"
  exit 1
fi

# Determine the target branch
if [ -z "$TARGET_BRANCH" ]; then
    TARGET_BRANCH="main" # Default to 'main' if not provided
    echo "No target branch specified, defaulting to branch: $TARGET_BRANCH"
else
    echo "Target branch specified: $TARGET_BRANCH"
fi

# --- DANGER ZONE: Resetting local state ---
echo "-----------------------------------------------------------------------"
echo "WARNING: ABOUT TO DISCARD ALL LOCAL UNCOMMITTED CHANGES AND UNTRACKED"
echo "         FILES IN '$FLUTTER_PROJECT_DIR' AND PULL FROM '$GIT_REMOTE_NAME/$TARGET_BRANCH'."
echo "         THIS ACTION CANNOT BE UNDONE."
echo "-----------------------------------------------------------------------"
# Add a small delay to allow user to cancel (Ctrl+C)
sleep 3

echo "Fetching latest changes from remote '$GIT_REMOTE_NAME'..."
if ! git fetch "$GIT_REMOTE_NAME"; then
    echo "Error: Failed to fetch from remote '$GIT_REMOTE_NAME'."
    cd "$ORIGINAL_DIR"
    exit 1
fi

echo "Resetting local state to match '$GIT_REMOTE_NAME/$TARGET_BRANCH'..."
# Make sure the target branch exists locally and is up-to-date with remote
# Checkout might fail if the branch doesn't exist locally yet, fetch should handle it
# git checkout "$TARGET_BRANCH" # Ensure we are on the target branch
if ! git checkout "$TARGET_BRANCH"; then
    echo "Error: Failed to checkout branch '$TARGET_BRANCH'. Does it exist locally?"
    cd "$ORIGINAL_DIR"
    exit 1
fi

if ! git reset --hard "$GIT_REMOTE_NAME/$TARGET_BRANCH"; then
    echo "Error: Failed to reset to $GIT_REMOTE_NAME/$TARGET_BRANCH."
    cd "$ORIGINAL_DIR"
    exit 1
fi
echo "Cleaning untracked files..."
git clean -fdx
echo "Local state reset and cleaned successfully."

# Pull again just to be absolutely sure (reset should have done it, but belt-and-suspenders)
echo "Pulling latest changes for branch '$TARGET_BRANCH' (final check)..."
if ! git pull "$GIT_REMOTE_NAME" "$TARGET_BRANCH"; then
    echo "Error: Failed to pull changes from $GIT_REMOTE_NAME/$TARGET_BRANCH."
    cd "$ORIGINAL_DIR"
    exit 1
fi
echo "Successfully pulled latest changes."
# --- End of DANGER ZONE ---


# Check if pubspec.yaml exists AFTER pull
PUBSPEC_PATH="$PUBSPEC_FILE" # Already relative to current dir
if [ ! -f "$PUBSPEC_PATH" ]; then
    echo "Error: '$PUBSPEC_PATH' not found in '$FLUTTER_PROJECT_DIR' after pull."
    cd "$ORIGINAL_DIR"
    exit 1
fi

# Update version in pubspec.yaml using sed
# This replaces the whole line starting with 'version:'
# Using .bak for macOS sed compatibility
echo "Updating $PUBSPEC_PATH version to $NEW_VERSION..."
if ! sed -i.bak "s/^version:.*/version: $NEW_VERSION/" "$PUBSPEC_PATH"; then
    echo "Error: Failed to update version in $PUBSPEC_PATH using sed."
    rm -f "$PUBSPEC_PATH.bak" # Clean up backup file on error
    cd "$ORIGINAL_DIR"
    exit 1
fi
rm -f "$PUBSPEC_PATH.bak" # Remove backup file on success
echo "$PUBSPEC_PATH updated successfully."

# Stage the change
echo "Staging $PUBSPEC_PATH..."
git add "$PUBSPEC_PATH"

# Commit the version change
VERSION_COMMIT_MESSAGE="$VERSION_COMMIT_MESSAGE_PREFIX $NEW_VERSION"
echo "Committing version change with message: '$VERSION_COMMIT_MESSAGE'..."
git commit -m "$VERSION_COMMIT_MESSAGE"

# Create Git tag
GIT_TAG="${GIT_TAG_PREFIX}${NEW_VERSION}"
echo "Creating Git tag: $GIT_TAG..."
if git rev-parse "$GIT_TAG" >/dev/null 2>&1; then
    echo "Error: Git tag '$GIT_TAG' already exists."
    # Consider reverting the commit here if needed
    echo "Attempting to revert the commit..."
    git reset --hard HEAD~1
    cd "$ORIGINAL_DIR"
    exit 1
fi
git tag "$GIT_TAG"
echo "Git tag '$GIT_TAG' created successfully."

echo "Generating changelog for Flutter project..."

# Generate changelog (update existing or create new)
# -r 0 ensures it processes up to the latest tag (which we just created)
if [ -f "$CHANGELOG_FILE" ]; then
  conventional-changelog -p angular -i "$CHANGELOG_FILE" -s -r 0
else
  conventional-changelog -p angular -o "$CHANGELOG_FILE" -r 0
fi

echo "Flutter changelog updated in $FLUTTER_PROJECT_DIR/$CHANGELOG_FILE"

# --- Commit Changelog Change ---
echo "Staging $CHANGELOG_FILE..."
if ! git add "$CHANGELOG_FILE"; then
    echo "Warning: Failed to stage $CHANGELOG_FILE. It might not have been modified."
    # Continue script execution, maybe no new changes to log
else
    # Only commit if staging was successful (i.e., file changed)
    CHANGELOG_COMMIT_MESSAGE="$CHANGELOG_COMMIT_MESSAGE_PREFIX $GIT_TAG"
    echo "Committing changelog update with message: '$CHANGELOG_COMMIT_MESSAGE'..."
    # Check if there are changes staged before committing
    if ! git diff --staged --quiet; then
        git commit -m "$CHANGELOG_COMMIT_MESSAGE"
        echo "Changelog commit created."
    else
        echo "No changes to commit for $CHANGELOG_FILE."
    fi
fi

# --- Pushing changes ---
echo "Pushing commit to $GIT_REMOTE_NAME/$TARGET_BRANCH..."
if ! git push "$GIT_REMOTE_NAME" "$TARGET_BRANCH"; then
    echo "Error: Failed to push commit to $GIT_REMOTE_NAME/$TARGET_BRANCH."
    echo "Manual push required: cd $FLUTTER_PROJECT_DIR && git push $GIT_REMOTE_NAME $TARGET_BRANCH"
    # Optionally exit or revert tag here
    # git tag -d "$GIT_TAG" # Example revert tag
    # git reset --hard HEAD~1 # Example revert commit
    cd "$ORIGINAL_DIR"
    exit 1 # Exit if commit push fails
fi

echo "Pushing tags to $GIT_REMOTE_NAME..."
if ! git push "$GIT_REMOTE_NAME" --tags; then
     echo "Warning: Failed to push tags to $GIT_REMOTE_NAME."
     echo "Manual push required: cd $FLUTTER_PROJECT_DIR && git push $GIT_REMOTE_NAME --tags"
     # Don't exit here, commit push succeeded
fi

echo "Commit and tags pushed successfully."
echo "Version update, commits, tag, changelog generation, and push complete."

# Navigate back to the original directory
echo "Changing back to original directory..."
cd "$ORIGINAL_DIR" || exit 1

echo "Script finished successfully." 