#!/bin/bash
# Install arch-skill locally
# Works with: OpenCode
# Usage: bash install.sh

set -e

SKILL_SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/.config/opencode/skills/arch"

echo "Installing arch-skill to ${DEST}..."

mkdir -p "${DEST}"

# Copy all skill files (avoid recursive copy of self into dest)
for item in "${SKILL_SRC}"/* "${SKILL_SRC}"/.[!.]*; do
    [ -e "$item" ] || continue
    base="$(basename "$item")"
    [ "$base" = ".git" ] && continue
    cp -r "$item" "${DEST}/"
done

echo "Done."
echo ""
echo "Skill installed at: ${DEST}"
echo "Restart your AI assistant to load the skill."
echo ""
echo "To verify:"
echo "  ls ${DEST}/SKILL.md"
