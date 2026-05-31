#!/bin/bash
# Install arch-skill for OpenCode
# Works with: OpenCode, Claude Code
# Usage:
#   Remote: curl -fsSL https://raw.githubusercontent.com/m20191201/arch-skill/main/install.sh | bash
#   Local:  bash install.sh

set -e

DEST="${HOME}/.config/opencode/skills/arch"
REPO="https://github.com/m20191201/arch-skill.git"
BRANCH="main"

echo "Installing arch-skill to ${DEST}..."
mkdir -p "$(dirname "${DEST}")"

if [ -d "${DEST}/.git" ]; then
    echo "Updating existing installation..."
    git -C "${DEST}" pull --ff-only origin "${BRANCH}"
elif [ -d "${DEST}" ]; then
    echo "Directory exists but no git repo. Removing and re-cloning..."
    rm -rf "${DEST}"
    git clone --depth 1 -b "${BRANCH}" "${REPO}" "${DEST}"
else
    git clone --depth 1 -b "${BRANCH}" "${REPO}" "${DEST}"
fi

echo ""
echo "Done. Restart your AI assistant to load the skill."
echo ""
echo "Repo:    ${REPO}"
echo "Path:    ${DEST}"
echo "Verify:  ls ${DEST}/SKILL.md"
