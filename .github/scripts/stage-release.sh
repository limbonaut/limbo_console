#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<-EOF
		Usage: $(basename "$0") [options] <version> [base-ref]

		Create a release branch, set the version in plugin.cfg, commit, and tag.
		Nothing is pushed.

		Arguments:
		  version    release version (eg: 0.8.0)
		  base-ref   branch to release from (default: master)

		Options:
		  -h, --help  show this help and exit
	EOF
}

die() {
	echo "error: $1" >&2
	exit "${2:-1}"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		-*) die "unknown option: $1" 2 ;;
		*) break ;;
	esac
	shift
done

version="${1:-}"
base_ref="${2:-master}"

[[ -n "$version" ]] || die "missing version argument" 2
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid version: $version (expected X.Y.Z)" 2

tag="v$version"
branch="release/$tag"

cd "$(git rev-parse --show-toplevel)"

[[ -f plugin.cfg ]] || die "plugin.cfg not found at repository root"
grep -q '^version=' plugin.cfg || die "no 'version=' line in plugin.cfg"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists"
git rev-parse -q --verify "refs/heads/$branch" >/dev/null && die "branch $branch already exists"

git fetch --quiet origin "$base_ref"
git switch -c "$branch" FETCH_HEAD

sed -i -E "s/^version=\"[^\"]*\"/version=\"$version\"/" plugin.cfg
grep -qx "version=\"$version\"" plugin.cfg || die "failed to set version in plugin.cfg"

git add plugin.cfg
git commit -m "Bump version to $version"
git tag "$tag"

echo "Staged $tag on branch $branch."
echo "Review, then push:  git push origin $branch && git push origin $tag"
