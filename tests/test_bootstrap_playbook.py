"""Unit tests for bootstrap and health check playbooks."""

from pathlib import Path

import pytest
import yaml


pytestmark = pytest.mark.unit


@pytest.fixture
def playbooks_dir():
    """Get the playbooks directory."""
    return Path(__file__).parent.parent / "playbooks"


@pytest.fixture
def bootstrap_playbook(playbooks_dir):
    """Load the bootstrap playbook."""
    with open(playbooks_dir / "docker-bootstrap.yml") as f:
        return yaml.safe_load(f)


@pytest.fixture
def health_check_playbook(playbooks_dir):
    """Load the health check playbook."""
    with open(playbooks_dir / "docker-check-health.yml") as f:
        return yaml.safe_load(f)


class TestBootstrapPlaybook:
    """Test docker-bootstrap.yml meta-playbook."""

    def test_playbook_syntax(self, bootstrap_playbook):
        """Verify bootstrap playbook has valid YAML syntax."""
        assert isinstance(bootstrap_playbook, list)
        assert len(bootstrap_playbook) >= 2

    def test_bootstrap_imports_foundation_and_services(self, bootstrap_playbook):
        """Verify bootstrap meta-playbook imports foundation, services, and health checks."""
        imported = [p.get("import_playbook") for p in bootstrap_playbook]

        assert "docker-bootstrap-foundation.yml" in imported
        assert "docker-deploy-services.yml" in imported
        assert "docker-check-health.yml" in imported

    def test_bootstrap_import_order(self, bootstrap_playbook):
        """Verify bootstrap runs foundation before services and health checks."""
        imported = [p.get("import_playbook") for p in bootstrap_playbook]

        assert imported[0] == "docker-bootstrap-foundation.yml"
        assert imported[1] == "docker-deploy-services.yml"


class TestHealthCheckPlaybook:
    """Test docker-check-health.yml playbook."""

    def test_playbook_syntax(self, health_check_playbook):
        """Verify health check playbook has valid YAML syntax."""
        assert isinstance(health_check_playbook, list)
        assert len(health_check_playbook) > 0

    def test_playbook_name(self, health_check_playbook):
        """Verify playbook has a name."""
        assert health_check_playbook[0].get("name") is not None
        assert "health" in health_check_playbook[0]["name"].lower()

    def test_playbook_hosts(self, health_check_playbook):
        """Verify playbook targets correct hosts."""
        assert health_check_playbook[0].get("hosts") == "all"

    def test_playbook_has_tasks(self, health_check_playbook):
        """Verify playbook has tasks defined."""
        tasks = health_check_playbook[0].get("tasks", [])
        assert len(tasks) > 0

    def test_health_check_validates_containers(self, health_check_playbook):
        """Verify playbook checks container health."""
        tasks = health_check_playbook[0].get("tasks", [])
        task_names = [t.get("name", "") for t in tasks]

        assert any("container" in name.lower() for name in task_names), "Missing container status checks"

    def test_health_check_validates_networks(self, health_check_playbook):
        """Verify playbook checks networks."""
        tasks = health_check_playbook[0].get("tasks", [])
        task_names = [t.get("name", "") for t in tasks]

        assert any("network" in name.lower() for name in task_names), "Missing network checks"

    def test_health_check_generates_report(self, health_check_playbook):
        """Verify playbook generates health report."""
        tasks = health_check_playbook[0].get("tasks", [])
        task_names = [t.get("name", "") for t in tasks]

        assert any("report" in name.lower() for name in task_names), "Missing report generation"

    def test_health_check_fails_on_unhealthy(self, health_check_playbook):
        """Verify playbook fails when infrastructure is unhealthy."""
        tasks = health_check_playbook[0].get("tasks", [])
        fail_tasks = [t for t in tasks if "fail" in t.get("name", "").lower()]

        assert len(fail_tasks) > 0, "No fail task for unhealthy status"


class TestNetworkDefinitions:
    """Test network definitions in compose files."""

    @pytest.fixture
    def stacks_dir(self):
        """Get the stacks directory."""
        return Path(__file__).parent.parent / "stacks"

    @pytest.mark.parametrize(
        "compose_file, service_name",
        [
            ("traefik/docker-compose.yml", "traefik"),
            ("docker-socket-proxy/docker-compose.yml", "docker-socket-proxy"),
            ("dockge/docker-compose.yml", "dockge"),
        ],
    )
    def test_service_defines_networks(self, stacks_dir, compose_file, service_name):
        """Verify each key service joins at least one Docker network."""
        with open(stacks_dir / compose_file) as f:
            content = yaml.safe_load(f)

        services = content.get("services", {})
        assert service_name in services, f"{compose_file} missing {service_name} service"

        service = services[service_name]
        networks = service.get("networks", [])
        assert networks, f"{compose_file} service {service_name} missing networks"

    def test_traefik_networks(self, stacks_dir):
        """Verify traefik service references expected networks."""
        with open(stacks_dir / "traefik/docker-compose.yml") as f:
            content = yaml.safe_load(f)

        service = content["services"]["traefik"]
        networks = service.get("networks", [])
        assert "traefik" in networks, "Traefik service missing traefik network"
        assert "socket-proxy" in networks, "Traefik service missing socket-proxy network"

    def test_socket_proxy_networks(self, stacks_dir):
        """Verify docker-socket-proxy service references expected networks."""
        with open(stacks_dir / "docker-socket-proxy/docker-compose.yml") as f:
            content = yaml.safe_load(f)

        service = content["services"]["docker-socket-proxy"]
        networks = service.get("networks", [])
        assert "socket-proxy" in networks, "docker-socket-proxy service missing socket-proxy network"

    def test_dockge_networks(self, stacks_dir):
        """Verify dockge service references expected networks."""
        with open(stacks_dir / "dockge/docker-compose.yml") as f:
            content = yaml.safe_load(f)

        service = content["services"]["dockge"]
        networks = service.get("networks", [])
        assert "socket-proxy" in networks, "dockge service missing socket-proxy network"
        assert "traefik" in networks, "dockge service missing traefik network"


class TestMakefileTargets:
    """Test Makefile has new targets."""

    @pytest.fixture
    def makefile(self):
        """Load the Makefile."""
        with open(Path(__file__).parent.parent / "Makefile") as f:
            return f.read()

    def test_docker_bootstrap_target(self, makefile):
        """Verify docker-bootstrap target exists."""
        assert "docker-bootstrap:" in makefile, "Missing docker-bootstrap target"
        assert "docker-bootstrap.yml" in makefile, "Target doesn't reference bootstrap playbook"

    def test_docker_health_target(self, makefile):
        """Verify docker-health target exists."""
        assert "docker-health:" in makefile, "Missing docker-health target"
        assert "docker-check-health.yml" in makefile, "docker-health target doesn't reference health check playbook"

    def test_help_messages(self, makefile):
        """Verify help messages are documented."""
        assert "Bootstrap infrastructure" in makefile, "Missing bootstrap help message"
        assert "health" in makefile, "Missing health check help message"
