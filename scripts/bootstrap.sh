#!/usr/bin/env bash
# Bootstrap script for Infrastructure Testing Harness
# Checks dependencies, installs packages, and prepares the test environment

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# JSON error output for missing dependencies
fail_with_json() {
  local missing_dep="$1"
  local action="$2"
  cat <<EOF
{
  "missing_dependency": "${missing_dep}",
  "action": "${action}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
  exit 1
}

# Check if running in CI
is_ci() {
  [ "${CI:-false}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ]
}

# Check dependencies
check_dependencies() {
  log_info "Checking dependencies..."

  # Check Python 3.12+
  if ! command -v python3 &>/dev/null; then
    fail_with_json "python3" "Install Python 3.12 or later"
  fi

  local python_version
  python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
  log_info "Python version: ${python_version}"

  if ! python3 -c 'import sys; exit(0 if sys.version_info >= (3, 11) else 1)'; then
    fail_with_json "python3" "Python 3.11+ required, found ${python_version}"
  fi

  # Check uv
  if ! command -v uv &>/dev/null; then
    fail_with_json "uv" "Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
  fi
  log_info "uv version: $(uv --version)"

  # Check Docker
  if ! command -v docker &>/dev/null; then
    if is_ci; then
      fail_with_json "docker" "Docker not available in CI environment"
    else
      log_warning "Docker not found, attempting to install..."
      install_docker
    fi
  fi

  # Test Docker daemon
  if ! docker ps &>/dev/null; then
    if is_ci; then
      fail_with_json "docker" "Docker daemon not accessible in CI"
    else
      log_warning "Docker daemon not running or not accessible"
      log_info "Checking Docker socket permissions..."
      if [ -S /var/run/docker.sock ]; then
        log_info "Attempting to start Docker service..."
        sudo service docker start 2>/dev/null || log_warning "Could not start Docker service automatically"
      else
        fail_with_json "docker" "Docker daemon not accessible. Ensure Docker is running and you have permission to access /var/run/docker.sock"
      fi
    fi
  fi

  log_success "All required dependencies are available"
}

# Install Docker (Debian/Ubuntu)
install_docker() {
  log_info "Installing Docker..."

  if [ ! -f /etc/os-release ]; then
    fail_with_json "docker" "Cannot determine OS. Please install Docker manually: https://docs.docker.com/engine/install/"
  fi

  # shellcheck source=/dev/null
  . /etc/os-release

  case "${ID}" in
  ubuntu | debian)
    log_info "Detected ${ID}, installing docker.io..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker.io docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "${USER}" || log_warning "Could not add user to docker group"
    ;;
  *)
    fail_with_json "docker" "Unsupported OS: ${ID}. Please install Docker manually: https://docs.docker.com/engine/install/"
    ;;
  esac

  log_success "Docker installed successfully"
}

# Install Python dependencies
install_python_deps() {
  log_info "Installing Python dependencies with uv..."

  # Sync dependencies
  uv sync --all-extras

  log_success "Python dependencies installed"
}

# Install Ansible collections
install_ansible_collections() {
  log_info "Installing Ansible collections and roles..."

  uv run ansible-galaxy collection install -r requirements.yml --force

  log_success "Ansible collections installed"
}

# Pull required Docker images
pull_docker_images() {
  log_info "Pulling required Docker images..."

  local images=(
    "debian:13-slim"
    "debian:bookworm-slim"
  )

  for image in "${images[@]}"; do
    log_info "Pulling ${image}..."
    docker pull "${image}" || log_warning "Could not pull ${image}"
  done

  log_success "Docker images pulled"
}

# Setup pre-commit hooks
setup_pre_commit() {
  if [ -f .pre-commit-config.yaml ]; then
    log_info "Installing pre-commit hooks..."
    uv run pre-commit install --install-hooks
    log_success "Pre-commit hooks installed"
  else
    log_warning "No .pre-commit-config.yaml found, skipping pre-commit setup"
  fi
}

# Create artifacts directory
create_artifacts_dir() {
  log_info "Creating artifacts directory..."
  mkdir -p tests/artifacts
  log_success "Artifacts directory ready"
}

# Generate environment report
generate_environment_report() {
  log_info "Generating environment report..."

  local report_file="tests/artifacts/environment_report.json"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat >"${report_file}" <<EOF
{
  "timestamp": "${timestamp}",
  "python_version": "$(python3 --version | awk '{print $2}')",
  "uv_version": "$(uv --version | awk '{print $2}')",
  "ansible_version": "$(uv run ansible --version | head -n1 | awk '{print $3}' | tr -d '[]')",
  "docker_version": "$(docker --version | awk '{print $3}' | tr -d ',')",
  "docker_compose_version": "$(docker compose version | awk '{print $4}')",
  "os_info": {
    "name": "$(uname -s)",
    "version": "$(uname -r)",
    "arch": "$(uname -m)"
  },
  "docker_images": $(docker images --format '{{json .}}' | jq -s '.')
}
EOF

  log_success "Environment report written to ${report_file}"
}

# Main execution
main() {
  log_info "=== Infrastructure Testing Harness Bootstrap ==="
  log_info ""

  check_dependencies
  install_python_deps
  install_ansible_collections
  pull_docker_images
  setup_pre_commit
  create_artifacts_dir
  generate_environment_report

  log_info ""
  log_success "=== Bootstrap completed successfully! ==="
  log_info ""
  log_info "Next steps:"
  log_info "  1. Run 'make test' to execute the test suite"
  log_info "  2. Run 'make lint' to check code quality"
  log_info "  3. See docs/GETTING_STARTED.md for more information"
}

main "$@"
