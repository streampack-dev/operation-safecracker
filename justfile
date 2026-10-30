maven := `if command -v mvnd >/dev/null 2>&1; then printf '%s' mvnd; else printf '%s' ./mvnw; fi`

default:
    just --list

clean:
    {{maven}} clean

# Build the jar without tests
build: clean
    {{maven}} -DskipTests=true package

# Build the jar with tests
test: clean
    {{maven}} package

# Releases come from main, up to date with origin's: never from a feature branch.
_on-main:
    #!/usr/bin/env bash
    set -euo pipefail
    branch="$(git branch --show-current)"
    if [[ "$branch" != "main" ]]; then
      echo "Release from main, not ${branch:-a detached HEAD}." >&2
      exit 1
    fi
    git fetch -q origin main
    if [[ -n "$(git rev-list HEAD..origin/main)" ]]; then
      echo "main is behind origin/main. Pull first." >&2
      exit 1
    fi

# A -SNAPSHOT version releases as itself first (1.0.0-SNAPSHOT -> 1.0.0); after that, level is
# patch, minor or major. The jar is built and tested, then deployed to Nexus. A failure before
# the deploy puts .mvn/maven.config back, so a retry doesn't bump again.
# Release: bump the version in .mvn/maven.config and deploy the jar to Nexus
release level="patch": _on-main
    #!/usr/bin/env bash
    set -euo pipefail
    level="{{level}}"
    config_file=".mvn/maven.config"
    case "$level" in
      patch|minor|major) ;;
      *) echo "release level must be one of: patch, minor, major" >&2; exit 1 ;;
    esac

    if ! git diff --quiet -- "$config_file"; then
      echo "$config_file has uncommitted changes (a failed release?). Commit or restore it first." >&2
      exit 1
    fi

    current="$(./mvnw -q help:evaluate -Dexpression=project.version -DforceStdout | tail -n 1)"
    if [[ "$current" == *-SNAPSHOT ]]; then
      next="${current%-SNAPSHOT}"
    else
      IFS=. read -r major minor patch <<<"$current"
      if [[ -z "${major:-}" || -z "${minor:-}" || -z "${patch:-}" ]]; then
        printf 'current version is not semantic: <%s>\n' "$current" >&2
        exit 1
      fi
      case "$level" in
        patch) next="${major}.${minor}.$((patch + 1))" ;;
        minor) next="${major}.$((minor + 1)).0" ;;
        major) next="$((major + 1)).0.0" ;;
      esac
    fi

    echo "Releasing $current -> $next"
    perl -0pi -e 's/^-Drevision=.*/-Drevision='"$next"'/m or die "failed to update revision\n"' "$config_file"
    trap 'status=$?; if [[ $status -ne 0 ]]; then git checkout -- "$config_file"; echo "Release failed; nothing was published, and $config_file is restored to $current." >&2; fi' EXIT

    echo "[1/2] Building and testing $next"
    {{maven}} clean verify
    echo "[2/2] Publishing"
    {{maven}} deploy -DskipTests
    trap - EXIT
    echo "Released $next: the jar is in Nexus. Commit $config_file."

# Each step runs only if the one before it worked.
# Release, then commit the new version in .mvn and push it
full-release level="patch":
    just release {{level}}
    git add .mvn
    git commit -m "updating release version"
    git push
