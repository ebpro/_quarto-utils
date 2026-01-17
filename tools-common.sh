#!/usr/bin/env bash
# Shared helpers for tools detection and display

set -euo pipefail

# ==================== Detection Functions ====================

detect_java() {
  if ! command -v java >/dev/null 2>&1; then return 1; fi
  local version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  local vendor=$(java -version 2>&1 | awk 'NR==1{print $1}')
  echo "| ☕ Java | \`$version\` ($vendor) |"
}

detect_maven() {
  if ! command -v mvn >/dev/null 2>&1; then return 1; fi
  local version=$(mvn --version | awk 'NR==1{print $3}')
  echo "| 🎯 Maven | \`$version\` |"
}

detect_gradle() {
  if ! command -v gradle >/dev/null 2>&1; then return 1; fi
  local version=$(gradle --version 2>/dev/null | awk '/Gradle / {print $2}')
  echo "| 🐘 Gradle | \`$version\` |"
}

detect_docker() {
  if ! command -v docker >/dev/null 2>&1; then return 1; fi
  local client=$(docker version --format '{{.Client.Version}}' 2>/dev/null)
  local server=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "N/A")
  echo "| 🐳 Docker | Client \`$client\` / Server \`$server\` |"
}

detect_git() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then return 1; fi
  local branch=$(git branch --show-current 2>/dev/null || echo "detached")
  local commit=$(git rev-parse --short HEAD 2>/dev/null)
  echo "| 🌿 Git | Branch \`$branch\` @ \`$commit\` |"
}

detect_sdk() {
  if [[ ! -d "$HOME/.sdkman" ]]; then return 1; fi
  echo "| 🔧 SDKMAN | Installed |"
}

detect_node() {
  if ! command -v node >/dev/null 2>&1; then return 1; fi
  local version=$(node --version)
  echo "| 🟢 Node.js | \`$version\` |"
}

detect_python() {
  if ! command -v python3 >/dev/null 2>&1; then return 1; fi
  local version=$(python3 --version | awk '{print $2}')
  echo "| 🐍 Python | \`$version\` |"
}

detect_env() {
  # OS / distro
  local os="unknown"
  if [[ -r /etc/os-release ]]; then
    os=$(awk -F= '/^PRETTY_NAME=/ {gsub(/\"/, "", $2); print $2; exit}' /etc/os-release)
  else
    os="$(uname -s) $(uname -r)"
  fi
  # architecture
  local arch=$(uname -m)
  # container detection
  local in_container="no"
  if [[ -f "/.dockerenv" ]] || grep -qaE "docker|kubepods|containerd" /proc/1/cgroup 2>/dev/null; then
    in_container="yes"
  fi
  echo "| 🖥️ Env | \`$os\` / \`$arch\` / Container: $in_container |"
}

# ==================== Display Functions ====================

display_tools() {
  local tools_list="$1"
  local style="${2:-compact}"

  echo ""
  echo "| Tool | Info |"
  echo "|------|------|"

  for tool in $tools_list; do
    case "$tool" in
      java) detect_java || echo "| ☕ Java | ❌ Not installed |" ;;
      maven) detect_maven || echo "| 🎯 Maven | ❌ Not installed |" ;;
      gradle) detect_gradle || echo "| 🐘 Gradle | ❌ Not installed |" ;;
      docker) detect_docker || echo "| 🐳 Docker | ❌ Not installed |" ;;
      git) detect_git || echo "| 🌿 Git | ❌ Not a git repo |" ;;
      sdk) detect_sdk || echo "| 🔧 SDKMAN | ❌ Not installed |" ;;
      node) detect_node || echo "| 🟢 Node.js | ❌ Not installed |" ;;
      python) detect_python || echo "| 🐍 Python | ❌ Not installed |" ;;
      env) detect_env || echo "| 🖥️ Env | ❌ Unable to detect |" ;;
    esac
  done

  echo ""
}

# ==================== Auto-detection ====================

auto_detect_tools() {
  local kernel="$1"
  case "$kernel" in
    java)
      display_tools "java maven gradle" "compact"
      ;;
    bash|zsh)
      display_tools "docker git" "compact"
      ;;
    python)
      display_tools "python" "compact"
      ;;
    *)
      echo "Unknown kernel: $kernel" >&2
      ;;
  esac
}

# ==================== Main Entry ====================

main() {
  local kernel="${1:-bash}"
  local tools="${2:-}"

  if [[ -n "$tools" ]]; then
    # Explicit tools list provided
    display_tools "$tools" "compact"
  else
    # Auto-detect based on kernel
    auto_detect_tools "$kernel"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
