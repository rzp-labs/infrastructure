#!/usr/bin/env bash
# Run Molecule test lifecycle and generate results

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

# Configuration
SCENARIOS_DIR="${SCENARIOS_DIR:-molecule}"
RESULTS_FILE="${RESULTS_FILE:-tests/artifacts/molecule_results.json}"
MOLECULE_CMD="${MOLECULE_CMD:-uv run molecule}"

# Parse arguments
SCENARIO="${1:-default}"
ACTION="${2:-test}"

# Initialize results
results_data='{
  "timestamp": "",
  "scenario": "",
  "phases": {},
  "idempotence_passed": false,
  "total_tests": 0,
  "passed_tests": 0,
  "failed_tests": 0,
  "errors": []
}'

add_result() {
  local phase="$1"
  local status="$2"
  local message="${3:-}"

  # Update results JSON
  results_data=$(echo "$results_data" | jq \
    --arg phase "$phase" \
    --arg status "$status" \
    --arg message "$message" \
    '.phases[$phase] = {"status": $status, "message": $message}')
}

run_phase() {
  local phase="$1"
  log_info "Running Molecule ${phase}..."

  if $MOLECULE_CMD "${phase}" --scenario-name "${SCENARIO}" 2>&1 | tee "/tmp/molecule_${phase}.log"; then
    log_success "${phase} completed successfully"
    add_result "${phase}" "passed" "Completed successfully"
    return 0
  else
    log_error "${phase} failed"
    local error_msg
    error_msg=$(tail -20 "/tmp/molecule_${phase}.log" | tr '\n' ' ')
    add_result "${phase}" "failed" "${error_msg}"
    return 1
  fi
}

check_idempotence() {
  log_info "Checking idempotence..."

  # Run converge again and check for changes
  if $MOLECULE_CMD converge --scenario-name "${SCENARIO}" 2>&1 | tee /tmp/molecule_idempotence.log; then
    # Parse output for "changed=0"
    if grep -q "changed=0" /tmp/molecule_idempotence.log; then
      log_success "Idempotence check passed (no changes on second run)"
      results_data=$(echo "$results_data" | jq '.idempotence_passed = true')
      add_result "idempotence" "passed" "No changes on second converge"
      return 0
    else
      log_warning "Idempotence check failed (changes detected on second run)"
      results_data=$(echo "$results_data" | jq '.idempotence_passed = false')
      add_result "idempotence" "failed" "Changes detected on second converge"
      return 1
    fi
  else
    log_error "Idempotence check failed to run"
    add_result "idempotence" "error" "Failed to run second converge"
    return 1
  fi
}

cleanup_residual_resources() {
  log_info "Checking for residual Docker resources..."

  local containers
  containers=$(docker ps -a --filter "label=molecule_scenario=${SCENARIO}" --format "{{.ID}}" 2>/dev/null || true)

  if [ -n "$containers" ]; then
    log_warning "Found residual containers, cleaning up..."
    echo "$containers" | xargs -r docker rm -f
  fi

  local networks
  networks=$(docker network ls --filter "label=molecule_scenario=${SCENARIO}" --format "{{.ID}}" 2>/dev/null || true)

  if [ -n "$networks" ]; then
    log_warning "Found residual networks, cleaning up..."
    echo "$networks" | xargs -r docker network rm
  fi

  local volumes
  volumes=$(docker volume ls --filter "label=molecule_scenario=${SCENARIO}" --format "{{.Name}}" 2>/dev/null || true)

  if [ -n "$volumes" ]; then
    log_warning "Found residual volumes, cleaning up..."
    echo "$volumes" | xargs -r docker volume rm
  fi

  log_success "Resource cleanup complete"
}

run_full_test() {
  log_info "=== Running Full Molecule Test Lifecycle ==="
  log_info "Scenario: ${SCENARIO}"
  log_info ""

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  results_data=$(echo "$results_data" | jq \
    --arg ts "$timestamp" \
    --arg scenario "$SCENARIO" \
    '.timestamp = $ts | .scenario = $scenario')

  local failed=0

  # Create
  if ! run_phase "create"; then
    failed=1
  fi

  # Prepare (if exists)
  if [ -f "${SCENARIOS_DIR}/${SCENARIO}/prepare.yml" ]; then
    if ! run_phase "prepare"; then
      failed=1
    fi
  fi

  # Converge
  if ! run_phase "converge"; then
    failed=1
  fi

  # Idempotence check
  if [ "$failed" -eq 0 ]; then
    if ! check_idempotence; then
      failed=1
    fi
  fi

  # Verify
  if [ -f "${SCENARIOS_DIR}/${SCENARIO}/verify.yml" ]; then
    if ! run_phase "verify"; then
      failed=1
    fi
  fi

  # Cleanup (always run)
  run_phase "cleanup" || true

  # Destroy (always run)
  run_phase "destroy" || true

  # Check for residual resources
  cleanup_residual_resources

  # Write results
  mkdir -p "$(dirname "$RESULTS_FILE")"
  echo "$results_data" | jq '.' >"$RESULTS_FILE"
  log_info "Results written to ${RESULTS_FILE}"

  if [ "$failed" -eq 0 ]; then
    log_success "=== All Molecule tests passed ==="
    return 0
  else
    log_error "=== Some Molecule tests failed ==="
    return 1
  fi
}

# Main execution
main() {
  case "$ACTION" in
  test)
    run_full_test
    ;;
  create | prepare | converge | verify | destroy | cleanup)
    run_phase "$ACTION"
    ;;
  idempotence)
    check_idempotence
    ;;
  *)
    log_error "Unknown action: $ACTION"
    echo "Usage: $0 [scenario] [action]"
    echo "  scenario: Molecule scenario name (default: default)"
    echo "  action: test|create|prepare|converge|verify|destroy|cleanup|idempotence"
    exit 1
    ;;
  esac
}

# Check dependencies
if ! command -v jq &>/dev/null; then
  log_error "jq is required but not installed"
  exit 1
fi

if ! command -v docker &>/dev/null; then
  log_error "docker is required but not installed"
  exit 1
fi

main "$@"
