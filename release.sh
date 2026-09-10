#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPO="eaangrino/kinewall-video-wallpaper"
readonly MAIN_BRANCH="main"
readonly METADATA_FILE="com.eaangrino.kinewall/metadata.json"

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

for command in git gh python3 sha256sum; do
    command -v "$command" >/dev/null 2>&1 || fail "Required command not found: $command"
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Run this script inside the KineWall Git repository."

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

[[ -f "$METADATA_FILE" ]] || fail "Missing $METADATA_FILE"

origin_url="$(git config --get remote.origin.url 2>/dev/null)" || fail "Git remote 'origin' is not configured."
[[ "$origin_url" == *"eaangrino/kinewall-video-wallpaper.git" ]] || \
    fail "Remote 'origin' does not point to $REPO: $origin_url"

current_branch="$(git branch --show-current)"
[[ "$current_branch" == "$MAIN_BRANCH" ]] || \
    fail "Release must be created from '$MAIN_BRANCH'. Current branch: '${current_branch:-detached HEAD}'"

if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "There are uncommitted tracked changes. Commit or discard them before releasing."
fi

gh auth status --hostname github.com >/dev/null 2>&1 || \
    fail "GitHub CLI is not authenticated. Run: gh auth login"

printf 'Fetching %s and tags...\n' "$MAIN_BRANCH"
git fetch origin "$MAIN_BRANCH" --tags --prune

head_sha="$(git rev-parse HEAD)"
origin_sha="$(git rev-parse "origin/$MAIN_BRANCH")"
[[ "$head_sha" == "$origin_sha" ]] || \
    fail "Local '$MAIN_BRANCH' does not match origin/$MAIN_BRANCH. Pull or push your changes first."

if ! version="$(python3 - "$METADATA_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as file:
    metadata = json.load(file)

version = metadata.get("KPlugin", {}).get("Version")
if not isinstance(version, str) or not version:
    raise SystemExit("KPlugin.Version is missing or invalid")

print(version)
PY
)"; then
    fail "Could not read KPlugin.Version from $METADATA_FILE"
fi

[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || \
    fail "KPlugin.Version must use X.Y.Z format. Found: $version"

readonly VERSION="$version"
readonly TAG="v$VERSION"
readonly TITLE="Kinewall - $VERSION"
readonly DIST_DIR="$repo_root/dist"
readonly ZIP_FILE="$DIST_DIR/kinewall-$VERSION.zip"

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
    fail "Remote tag $TAG already exists. Refusing to overwrite it."
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    fail "GitHub release $TAG already exists. Refusing to overwrite it."
fi

mkdir -p "$DIST_DIR"
rm -f "$ZIP_FILE"

printf 'Creating %s from commit %s...\n' "$(basename "$ZIP_FILE")" "$head_sha"
git archive \
    --format=zip \
    --prefix="kinewall-$VERSION/" \
    --output="$ZIP_FILE" \
    "$head_sha"

[[ -s "$ZIP_FILE" ]] || fail "ZIP archive was not created correctly."

printf '\nArchive SHA-256:\n'
sha256sum "$ZIP_FILE"

printf '\nCreating GitHub release %s...\n' "$TAG"
gh release create "$TAG" "$ZIP_FILE" \
    --repo "$REPO" \
    --target "$head_sha" \
    --title "$TITLE" \
    --generate-notes

printf '\nFetching the newly created tag locally...\n'
git fetch origin "refs/tags/$TAG:refs/tags/$TAG"

printf '\nRelease created successfully:\n'
gh release view "$TAG" --repo "$REPO"
