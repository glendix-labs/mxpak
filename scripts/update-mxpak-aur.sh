#!/usr/bin/env bash
#
# Prepare, validate, commit, or publish the mxpak-bin AUR package for one
# tagged GitHub release. The default mode is a local dry run.

# Keep `sh scripts/update-mxpak-aur.sh` working when /bin/sh is not Bash.
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PACKAGE_NAME="${AUR_PACKAGE_NAME:-mxpak-bin}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-glendix-labs/mxpak}"
RELEASE_TAG="${MXPAK_RELEASE_TAG:-${GITHUB_REF_NAME:-}}"
RELEASE_ASSET="${MXPAK_RELEASE_ASSET:-mxp}"
AUR_TEMPLATE_DIR="${AUR_TEMPLATE_DIR:-$REPOSITORY_DIR/aur}"
AUR_WORK_DIR="${AUR_WORK_DIR:-$REPOSITORY_DIR/.aur-work}"
AUR_FETCH_BASE="${AUR_FETCH_BASE:-https://aur.archlinux.org}"
AUR_PUSH_BASE="${AUR_PUSH_BASE:-ssh://aur@aur.archlinux.org}"
GITHUB_TOKEN_VALUE="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

MODE="prepare"
VERIFY_SOURCE=0
INITIALIZE_EMPTY=0
OFFLINE=0
TMP_DIR=""
CHECKOUT_DIR=""
ASSET_SHA256=""
LICENSE_SHA256=""
UPSTREAM_VERSION=""
UPSTREAM_PKGREL=""
UPSTREAM_REF=""
PACKAGE_RELEASE=1

usage() {
    cat <<'EOF'
Usage:
  bash scripts/update-mxpak-aur.sh [options]

Options:
  --tag TAG             GitHub release tag to package (for example v1.0.0)
  --work-dir PATH       AUR checkout directory
  --verify-source       Download the release asset and verify its SHA-256
  --initialize-empty    Allow the first commit to an empty AUR repository
  --offline             Prepare files without contacting AUR
  --commit              Create a local AUR commit, but do not push
  --push                Commit and push the package to AUR
  -h, --help            Show this help

Environment:
  GITHUB_TOKEN or GH_TOKEN
                        Optional GitHub API token
  GITHUB_REPOSITORY     Upstream owner/repository
                        (default: glendix-labs/mxpak)
  GITHUB_API_BASE       Override the GitHub Releases API base for testing
  MXPAK_RELEASE_TAG     Same as --tag
  MXPAK_RELEASE_ASSET   GitHub release asset name (default: mxp)
  AUR_PACKAGE_NAME      AUR package name (default: mxpak-bin)
  AUR_WORK_DIR          Same as --work-dir
  AUR_FETCH_BASE        AUR read URL base
                        (default: https://aur.archlinux.org)
  AUR_PUSH_BASE         AUR push URL base
                        (default: ssh://aur@aur.archlinux.org)

Examples:
  # Prepare and inspect the package without committing or pushing
  bash scripts/update-mxpak-aur.sh --tag v1.0.0

  # Validate an existing AUR package update without publishing it
  bash scripts/update-mxpak-aur.sh --tag v1.0.0 --verify-source

  # Prepare files while AUR is unavailable
  bash scripts/update-mxpak-aur.sh --tag v1.0.0 --verify-source --offline

  # First publication after creating the empty AUR package repository
  bash scripts/update-mxpak-aur.sh \
    --tag v1.0.0 \
    --initialize-empty \
    --verify-source \
    --push
EOF
}

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}

trap cleanup EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        die "required command not found: $1"
}

while (($# > 0)); do
    case "$1" in
        --tag)
            (($# >= 2)) || die "--tag requires a value"
            RELEASE_TAG="$2"
            shift 2
            ;;
        --tag=*)
            RELEASE_TAG="${1#*=}"
            shift
            ;;
        --work-dir)
            (($# >= 2)) || die "--work-dir requires a path"
            AUR_WORK_DIR="$2"
            shift 2
            ;;
        --work-dir=*)
            AUR_WORK_DIR="${1#*=}"
            shift
            ;;
        --verify-source)
            VERIFY_SOURCE=1
            shift
            ;;
        --initialize-empty)
            INITIALIZE_EMPTY=1
            shift
            ;;
        --offline)
            OFFLINE=1
            shift
            ;;
        --commit)
            MODE="commit"
            shift
            ;;
        --push)
            MODE="push"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

if ((OFFLINE == 1)) && [[ "$MODE" != "prepare" ]]; then
    die "--offline cannot be combined with --commit or --push"
fi

[[ "$GITHUB_REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] ||
    die "invalid GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
[[ "$PACKAGE_NAME" =~ ^[a-z0-9@._+-]+$ ]] ||
    die "invalid AUR_PACKAGE_NAME: $PACKAGE_NAME"
[[ "$RELEASE_ASSET" =~ ^[A-Za-z0-9._+-]+$ ]] ||
    die "invalid MXPAK_RELEASE_ASSET: $RELEASE_ASSET"
[[ "$RELEASE_TAG" =~ ^v([0-9]+(\.[0-9]+){2})$ ]] ||
    die "release tag must be v-prefixed semantic version: ${RELEASE_TAG:-<empty>}"

VERSION="${BASH_REMATCH[1]}"

for command_name in bash cmp curl git jq makepkg sha256sum sed grep awk mktemp; do
    require_command "$command_name"
done

[[ -f "$AUR_TEMPLATE_DIR/PKGBUILD" ]] ||
    die "AUR PKGBUILD template not found: $AUR_TEMPLATE_DIR/PKGBUILD"
[[ -f "$REPOSITORY_DIR/LICENCE" ]] ||
    die "license file not found: $REPOSITORY_DIR/LICENCE"

mkdir -p -- "$AUR_WORK_DIR"
AUR_WORK_DIR="$(cd -- "$AUR_WORK_DIR" && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mxpak-aur-update.XXXXXXXX")"

API_BASE="${GITHUB_API_BASE:-https://api.github.com/repos/$GITHUB_REPOSITORY}"
RELEASE_JSON="$TMP_DIR/release.json"
ASSET_FILE="$TMP_DIR/$RELEASE_ASSET"
LICENSE_SHA256="$(sha256sum "$REPOSITORY_DIR/LICENCE" | awk '{print $1}')"
[[ "$LICENSE_SHA256" =~ ^[0-9a-f]{64}$ ]] ||
    die "license file returned an invalid SHA-256"

api_download() {
    local url="$1"
    local destination="$2"
    local -a headers=(
        -H "Accept: application/vnd.github+json"
        -H "X-GitHub-Api-Version: 2022-11-28"
        -H "User-Agent: mxpak-aur-updater"
    )

    if [[ -n "$GITHUB_TOKEN_VALUE" ]]; then
        headers+=(-H "Authorization: Bearer $GITHUB_TOKEN_VALUE")
    fi

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 3 \
        --retry-all-errors \
        "${headers[@]}" \
        --output "$destination" \
        "$url"
}

download_file() {
    local url="$1"
    local destination="$2"

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 3 \
        --retry-all-errors \
        --output "$destination" \
        "$url"
}

read_assignment() {
    local file="$1"
    local name="$2"
    local line
    local count

    count="$(grep -Ec "^${name}=" "$file" || true)"
    [[ "$count" == "1" ]] ||
        die "expected one ${name}= assignment in $file, found $count"

    line="$(grep -E "^${name}=" "$file")"
    line="${line#*=}"
    line="${line#\"}"
    line="${line%\"}"
    line="${line#\'}"
    line="${line%\'}"
    printf '%s\n' "$line"
}

replace_assignment() {
    local file="$1"
    local name="$2"
    local value="$3"
    local count

    count="$(grep -Ec "^${name}=" "$file" || true)"
    [[ "$count" == "1" ]] ||
        die "expected one ${name}= assignment in $file, found $count"

    sed -E -i "s|^${name}=.*$|${name}=${value}|" "$file"
}

release_asset_url() {
    jq -er \
        --arg name "$RELEASE_ASSET" \
        '[.assets[] | select(.name == $name)][0].browser_download_url' \
        "$RELEASE_JSON" ||
        die "GitHub release $RELEASE_TAG is missing asset: $RELEASE_ASSET"
}

resolve_release() {
    local actual_tag
    local asset_url
    local digest

    log "==> Resolving GitHub release: $RELEASE_TAG"
    api_download \
        "$API_BASE/releases/tags/$RELEASE_TAG" \
        "$RELEASE_JSON"

    actual_tag="$(jq -er '.tag_name' "$RELEASE_JSON")"
    [[ "$actual_tag" == "$RELEASE_TAG" ]] ||
        die "GitHub returned release tag $actual_tag, expected $RELEASE_TAG"
    [[ "$(jq -er '.draft' "$RELEASE_JSON")" == "false" ]] ||
        die "GitHub release is still a draft: $RELEASE_TAG"
    [[ "$(jq -er '.prerelease' "$RELEASE_JSON")" == "false" ]] ||
        die "GitHub release is a prerelease: $RELEASE_TAG"

    asset_url="$(release_asset_url)"
    digest="$(
        jq -r \
            --arg name "$RELEASE_ASSET" \
            '[.assets[] | select(.name == $name)][0].digest // empty' \
            "$RELEASE_JSON"
    )"

    download_file "$asset_url" "$ASSET_FILE"
    ASSET_SHA256="$(sha256sum "$ASSET_FILE" | awk '{print $1}')"
    [[ "$ASSET_SHA256" =~ ^[0-9a-f]{64}$ ]] ||
        die "downloaded asset returned an invalid SHA-256"

    if [[ -n "$digest" ]]; then
        [[ "$digest" =~ ^sha256:([0-9a-f]{64})$ ]] ||
            die "GitHub returned an unsupported asset digest: $digest"
        [[ "${BASH_REMATCH[1]}" == "$ASSET_SHA256" ]] ||
            die "downloaded asset does not match the GitHub asset digest"
    fi
}

remote_ref_exists() {
    local directory="$1"

    git -C "$directory" show-ref \
        --verify \
        --quiet \
        refs/remotes/source/master ||
        git -C "$directory" show-ref \
            --verify \
            --quiet \
            refs/remotes/source/main
}

prepare_checkout() {
    local checkout="$AUR_WORK_DIR/$PACKAGE_NAME"
    local status
    local upstream
    local ahead
    local behind

    if [[ -e "$checkout" && ! -d "$checkout/.git" ]]; then
        die "$checkout exists but is not an AUR Git checkout"
    fi

    if ((OFFLINE == 1)); then
        log "==> Preparing offline AUR checkout: $PACKAGE_NAME"
        if [[ ! -d "$checkout/.git" ]]; then
            mkdir -p -- "$checkout"
            git -C "$checkout" init -b master
        fi

        status="$(git -C "$checkout" status --porcelain)"
        [[ -z "$status" ]] ||
            die "offline AUR checkout has uncommitted changes: $checkout"$'\n'"$status"

        cat >"$checkout/.git/info/exclude" <<'EOF'
*
!.SRCINFO
!LICENCE
!PKGBUILD
EOF
        CHECKOUT_DIR="$checkout"
        return
    fi

    if [[ ! -d "$checkout/.git" ]]; then
        log "==> Cloning AUR package: $PACKAGE_NAME"
        git clone "${AUR_FETCH_BASE%/}/${PACKAGE_NAME}.git" "$checkout"
    else
        log "==> Updating AUR checkout: $PACKAGE_NAME"
    fi

    status="$(git -C "$checkout" status --porcelain)"
    [[ -z "$status" ]] ||
        die "AUR checkout has uncommitted changes: $checkout"$'\n'"$status"

    git -C "$checkout" remote get-url source >/dev/null 2>&1 ||
        git -C "$checkout" remote add \
            source \
            "${AUR_FETCH_BASE%/}/${PACKAGE_NAME}.git"
    git -C "$checkout" remote set-url \
        source \
        "${AUR_FETCH_BASE%/}/${PACKAGE_NAME}.git"
    git -C "$checkout" remote set-url \
        origin \
        "${AUR_PUSH_BASE%/}/${PACKAGE_NAME}.git"
    git -C "$checkout" fetch --prune source

    git -C "$checkout" update-ref \
        -d \
        refs/remotes/origin/master
    git -C "$checkout" update-ref \
        -d \
        refs/remotes/origin/main
    for branch in master main; do
        if git -C "$checkout" show-ref \
            --verify \
            --quiet \
            "refs/remotes/source/$branch"; then
            git -C "$checkout" update-ref \
                "refs/remotes/origin/$branch" \
                "$(git -C "$checkout" rev-parse "refs/remotes/source/$branch")"
        fi
    done

    if remote_ref_exists "$checkout"; then
        upstream="$(
            git -C "$checkout" \
                for-each-ref \
                --format='%(refname:short)' \
                refs/remotes/origin/master \
                refs/remotes/origin/main |
                head -n 1
        )"
        [[ -n "$upstream" ]] ||
            die "AUR repository has no supported master or main branch"
        UPSTREAM_REF="$upstream"

        if git -C "$checkout" rev-parse --verify HEAD >/dev/null 2>&1; then
            ahead="$(git -C "$checkout" rev-list --count "${upstream}..HEAD")"
            behind="$(git -C "$checkout" rev-list --count "HEAD..${upstream}")"
            if ((ahead > 0 && behind > 0)); then
                die "$checkout has diverged from $upstream; resolve it manually"
            fi
            if ((ahead > 0)) && [[ "$MODE" != "push" ]]; then
                die "$checkout has $ahead unpushed commit(s); rerun with --push or handle them manually"
            fi
            ((behind == 0)) ||
                git -C "$checkout" merge --ff-only "$upstream"
        else
            git -C "$checkout" checkout -B master "$upstream"
        fi

        load_upstream_package_metadata "$checkout" "$upstream"
    else
        ((INITIALIZE_EMPTY == 1)) ||
            die "AUR repository is empty; create/adopt $PACKAGE_NAME and rerun with --initialize-empty"

        if ! git -C "$checkout" symbolic-ref -q HEAD >/dev/null 2>&1; then
            git -C "$checkout" symbolic-ref HEAD refs/heads/master
        fi
    fi

    cat >"$checkout/.git/info/exclude" <<'EOF'
*
!.SRCINFO
!LICENCE
!PKGBUILD
EOF

    CHECKOUT_DIR="$checkout"
}

load_upstream_package_metadata() {
    local directory="$1"
    local upstream="$2"
    local upstream_pkgbuild="$TMP_DIR/upstream-PKGBUILD"
    local upstream_srcinfo="$TMP_DIR/upstream-SRCINFO"

    git -C "$directory" show "$upstream:PKGBUILD" >"$upstream_pkgbuild" ||
        die "$upstream does not contain PKGBUILD"
    git -C "$directory" show "$upstream:.SRCINFO" >"$upstream_srcinfo" ||
        die "$upstream does not contain .SRCINFO"

    validate_package_files "$upstream_pkgbuild" "$upstream_srcinfo" "$PACKAGE_NAME"

    UPSTREAM_VERSION="$(read_assignment "$upstream_pkgbuild" pkgver)"
    UPSTREAM_PKGREL="$(read_assignment "$upstream_pkgbuild" pkgrel)"
    [[ "$UPSTREAM_PKGREL" =~ ^[0-9]+$ ]] ||
        die "pkgrel is not numeric in $upstream:PKGBUILD"
}

validate_package_files() {
    local pkgbuild="$1"
    local srcinfo="$2"
    local expected_package="$3"
    local validation_directory
    local generated_srcinfo

    validation_directory="$(mktemp -d "$TMP_DIR/validate.XXXXXXXX")"
    generated_srcinfo="$validation_directory/.SRCINFO.generated"
    cp -- "$pkgbuild" "$validation_directory/PKGBUILD"
    cp -- "$srcinfo" "$validation_directory/.SRCINFO"

    [[ "$(read_assignment "$validation_directory/PKGBUILD" pkgname)" == "$expected_package" ]] ||
        die "$pkgbuild has an unexpected pkgname"

    (
        cd -- "$validation_directory"
        makepkg --printsrcinfo >"$generated_srcinfo"
        makepkg --packagelist >/dev/null
    )
    cmp -s "$validation_directory/.SRCINFO" "$generated_srcinfo" ||
        die "$srcinfo is stale or does not match $pkgbuild"
}

render_package() {
    local pkgbuild="$CHECKOUT_DIR/PKGBUILD"
    local generated_srcinfo="$TMP_DIR/.SRCINFO"

    log "==> Rendering $PACKAGE_NAME $VERSION"
    cp -- "$AUR_TEMPLATE_DIR/PKGBUILD" "$pkgbuild"
    cp -- "$REPOSITORY_DIR/LICENCE" "$CHECKOUT_DIR/LICENCE"

    if [[ -n "$UPSTREAM_REF" ]] &&
        ! git -C "$CHECKOUT_DIR" diff --quiet "$UPSTREAM_REF" -- LICENCE; then
        die "AUR LICENCE differs from the repository LICENCE; review the license change manually"
    fi

    replace_assignment "$pkgbuild" pkgname "$PACKAGE_NAME"
    replace_assignment "$pkgbuild" pkgver "$VERSION"
    PACKAGE_RELEASE=1
    if [[ "$UPSTREAM_VERSION" == "$VERSION" ]]; then
        PACKAGE_RELEASE="$UPSTREAM_PKGREL"
    fi
    replace_assignment "$pkgbuild" pkgrel "$PACKAGE_RELEASE"
    replace_assignment \
        "$pkgbuild" \
        sha256sums \
        "('$ASSET_SHA256' '$LICENSE_SHA256')"

    generate_srcinfo "$generated_srcinfo"

    if [[ "$UPSTREAM_VERSION" == "$VERSION" ]] && package_files_changed; then
        PACKAGE_RELEASE="$((UPSTREAM_PKGREL + 1))"
        replace_assignment "$pkgbuild" pkgrel "$PACKAGE_RELEASE"
        generate_srcinfo "$generated_srcinfo"
    fi

    log "    package release: ${VERSION}-${PACKAGE_RELEASE}"

    [[ "$(read_assignment "$pkgbuild" pkgname)" == "$PACKAGE_NAME" ]] ||
        die "rendered PKGBUILD has the wrong pkgname"
    [[ "$(read_assignment "$pkgbuild" pkgver)" == "$VERSION" ]] ||
        die "rendered PKGBUILD has the wrong pkgver"
    cmp -s \
        "$CHECKOUT_DIR/.SRCINFO" \
        <(cd -- "$CHECKOUT_DIR" && makepkg --printsrcinfo) ||
        die ".SRCINFO does not match PKGBUILD"

    git -C "$CHECKOUT_DIR" diff --check
}

generate_srcinfo() {
    local generated_srcinfo="$1"

    (
        cd -- "$CHECKOUT_DIR"
        makepkg --printsrcinfo >"$generated_srcinfo"
        makepkg --packagelist >/dev/null
    )

    [[ -s "$generated_srcinfo" ]] ||
        die "makepkg generated an empty .SRCINFO"
    mv -- "$generated_srcinfo" "$CHECKOUT_DIR/.SRCINFO"
}

verify_source() {
    log "==> Verifying GitHub release asset with makepkg"
    (
        cd -- "$CHECKOUT_DIR"
        makepkg --verifysource
    )
}

package_files_changed() {
    ! git -C "$CHECKOUT_DIR" diff --quiet -- PKGBUILD .SRCINFO LICENCE ||
        [[ -n "$(
            git -C "$CHECKOUT_DIR" \
                ls-files \
                --others \
                --exclude-standard \
                -- \
                PKGBUILD .SRCINFO LICENCE
        )" ]]
}

show_changes() {
    if ! package_files_changed; then
        log
        log "$PACKAGE_NAME is already up to date."
        return 1
    fi

    log
    log "--- $PACKAGE_NAME changes ---"
    git -C "$CHECKOUT_DIR" --no-pager diff -- PKGBUILD .SRCINFO LICENCE
    git -C "$CHECKOUT_DIR" status --short
    return 0
}

commit_exists() {
    git -C "$CHECKOUT_DIR" rev-parse --verify HEAD >/dev/null 2>&1
}

ahead_of_remote() {
    local upstream

    commit_exists || return 1
    remote_ref_exists "$CHECKOUT_DIR" || return 0

    upstream="$(
        git -C "$CHECKOUT_DIR" \
            for-each-ref \
            --format='%(refname:short)' \
            refs/remotes/origin/master \
            refs/remotes/origin/main |
            head -n 1
    )"
    [[ -n "$upstream" ]] ||
        die "AUR repository has no supported master or main branch"

    (( "$(git -C "$CHECKOUT_DIR" rev-list --count "${upstream}..HEAD")" > 0 ))
}

commit_changes() {
    git -C "$CHECKOUT_DIR" add PKGBUILD .SRCINFO LICENCE
    git -C "$CHECKOUT_DIR" commit \
        -m "Update $PACKAGE_NAME to ${VERSION}-${PACKAGE_RELEASE}"
}

resolve_release
prepare_checkout
render_package

if ((VERIFY_SOURCE == 1)); then
    verify_source
fi

HAS_CHANGES=0
if show_changes; then
    HAS_CHANGES=1
fi

if [[ "$MODE" == "commit" || "$MODE" == "push" ]]; then
    if ((HAS_CHANGES == 1)); then
        log
        log "==> Creating AUR commit"
        commit_changes
    elif [[ "$MODE" == "commit" ]]; then
        exit 0
    fi
fi

if [[ "$MODE" == "push" ]]; then
    if ! ahead_of_remote; then
        log
        log "$PACKAGE_NAME is already published; nothing to push."
        exit 0
    fi
    log
    log "==> Pushing $PACKAGE_NAME to AUR"
    git -C "$CHECKOUT_DIR" push \
        origin \
        HEAD:master
    log
    log "AUR update complete."
elif [[ "$MODE" == "commit" ]]; then
    log
    log "Local AUR commit created under: $CHECKOUT_DIR"
    log "No repository was pushed."
else
    ((HAS_CHANGES == 1)) || exit 0
    log
    log "Changes prepared under: $CHECKOUT_DIR"
    log "No commit or push was performed."
fi
