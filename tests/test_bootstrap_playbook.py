"""Unit tests for bootstrap and health check playbooks."""

import json
import re
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
    """Test docker-bootstrap.yml playbook."""

    def test_playbook_syntax(self, bootstrap_playbook):
        """Verify bootstrap playbook has valid YAML syntax."""
        assert isinstance(bootstrap_playbook, list)
        assert len(bootstrap_playbook) > 0

    def test_playbook_name(self, bootstrap_playbook):
        """Verify playbook has a name."""
        assert bootstrap_playbook[0].get("name") is not None
        assert "bootstrap" in bootstrap_playbook[0]["name"].lower()

    def test_playbook_hosts(self, bootstrap_playbook):
        """Verify playbook targets correct hosts."""
        assert bootstrap_playbook[0].get("hosts") == "all"

    def test_playbook_has_tasks(self, bootstrap_playbook):
        """Verify playbook has tasks defined."""
        tasks = bootstrap_playbook[0].get("tasks", [])
        assert len(tasks) > 0

    def test_playbook_has_bootstrap_stages(self, bootstrap_playbook):
        """Verify playbook has all deployment stages."""
        tasks = bootstrap_playbook[0].get("tasks", [])
        task_names = [t.get("name", "") for t in tasks]

        assert any("Foundation" in name for name in task_names), "Missing foundation stage"
        assert any("OAuth" in name for name in task_names), "Missing OAuth setup stage"
        assert any("Proxy" in name for name in task_names), "Missing proxy layer stage"
        assert any("Services" in name for name in task_names), "Missing services stage"

    def test_foundation_stage_tasks(self, bootstrap_playbook):
        """Verify foundation stage has required tasks."""
        tasks = bootstrap_playbook[0].get("tasks", [])
        foundation_tasks = [t for t in tasks if "Foundation" in t.get("name", "")]

        assert len(foundation_tasks) > 0, "No foundation stage tasks"

        task_names = [t.get("name", "") for t in foundation_tasks]
        assert any("Synchronize" in name for name in task_names), "Missing sync task"
        assert any("docker-socket-proxy" in name for name in task_names), "Missing socket-proxy deploy"
        assert any("zitadel" in name.lower() for name in task_names), "Missing zitadel deploy"

    def test_oauth_stage_tasks(self, bootstrap_playbook):
        """Verify OAuth setup stage is present."""
        tasks = bootstrap_playbook[0].get("tasks", [])
        oauth_tasks = [t for t in tasks if "OAuth" in t.get("name", "")]

        assert len(oauth_tasks) > 0, "No OAuth setup tasks"

    def test_proxy_stage_tasks(self, bootstrap_playbook):
        """Verify proxy layer stage is present."""
        tasks = bootstrap_playbook[0].get("tasks", [])
        proxy_tasks = [t for t in tasks if "Proxy" in t.get("name", "")]

        assert len(proxy_tasks) > 0, "No proxy layer tasks"

    def test_services_stage_tasks(self, bootstrap_playbook):
        """Verify services stage is present."""
        tasks = bootstrap_playbook[0].get("tasks", [])
        service_tasks = [t for t in tasks if "Services" in t.get("name", "")]

        assert len(service_tasks) > 0, "No services stage tasks"


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
        "compose_file",
        [
            "traefik/docker-compose.yml",
            "docker-socket-proxy/docker-compose.yml",
            "dockge/docker-compose.yml",
            "zitadel/docker-compose.yml",
        ],
    )
    def test_compose_file_has_networks_section(self, stacks_dir, compose_file):
        """Verify each compose file has networks section."""
        with open(stacks_dir / compose_file) as f:
            content = yaml.safe_load(f)

        assert "networks" in content, f"{compose_file} missing networks section"

    def test_traefik_networks(self, stacks_dir):
        """Verify traefik compose file references correct networks."""
        with open(stacks_dir / "traefik/docker-compose.yml") as f:
            content = yaml.safe_load(f)

        networks = content.get("networks", {})
        assert "traefik" in networks, "Missing traefik network"
        assert "socket-proxy" in networks, "Missing socket-proxy network"

    def test_socket_proxy_networks(self, stacks_dir):
        """Verify docker-socket-proxy compose file references correct networks."""
        with open(stacks_dir / "docker-socket-proxy/docker-compose.yml") as f:
            content = yaml.safe_load(f)

        networks = content.get("networks", {})
        assert "socket-proxy" in networks, "Missing socket-proxy network"

    def test_dockge_networks(self, stacks_dir):
        """Verify dockge compose file references correct networks."""
        with open(stacks_dir / "dockge/docker-compose.yml") as f:
            content = yaml.safe_load(f)

        networks = content.get("networks", {})
        assert "socket-proxy" in networks, "Missing socket-proxy network"
        assert "traefik" in networks, "Missing traefik network"

    def test_zitadel_networks(self, stacks_dir):
        """Verify zitadel compose file references correct networks."""
        with open(stacks_dir / "zitadel/docker-compose.yml") as f:
            content = yaml.safe_load(f)

        networks = content.get("networks", {})
        assert "zitadel" in networks, "Missing zitadel network"
        assert "traefik" in networks, "Missing traefik network"


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

    def test_docker_check_health_target(self, makefile):
        """Verify docker-check-health target exists."""
        assert "docker-check-health:" in makefile, "Missing docker-check-health target"
        assert "docker-check-health.yml" in makefile, "Target doesn't reference health check playbook"

    def test_help_messages(self, makefile):
        """Verify help messages are documented."""
        assert "Bootstrap infrastructure" in makefile, "Missing bootstrap help message"
        assert "health" in makefile, "Missing health check help message"
