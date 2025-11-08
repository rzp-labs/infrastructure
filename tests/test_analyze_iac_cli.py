"""CLI tests for the analyze_iac tool."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Iterable

import pytest

from scripts import analyze_iac


pytestmark = pytest.mark.unit


def _write_yaml(path: Path, lines: Iterable[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).strip() + "\n", encoding="utf-8")


def _create_project(tmp_path: Path, *, with_issues: bool) -> Path:
    playbook_path = tmp_path / "playbooks" / "site.yml"
    compose_path = tmp_path / "stacks" / "app" / "docker-compose.yml"

    if with_issues:
        playbook_lines = [
            "- name: Deploy Traefik stack",
            "  hosts: traefik",
            "  tasks:",
            "    - name: Pull Traefik image",
            "      community.docker.docker_image:",
            "        name: traefik:v3.2",
            "    - name: Insecure Docker access",
            "      shell: docker ps",
            "    - shell: systemctl restart traefik",
        ]
        compose_lines = [
            "services:",
            "  traefik:",
            "    image: traefik:v3.2",
            "    volumes:",
            "      - /var/run/docker.sock:/var/run/docker.sock",
            "    privileged: true",
            "  traefik-oauth2-proxy:",
            "    image: quay.io/oauth2-proxy/oauth2-proxy:v7.6.0",
            "    network_mode: host",
            "networks:",
            "  traefik:",
            "  socket-proxy:",
            "networks:",
            "  traefik:",
            "  socket-proxy:",
        ]
    else:
        playbook_lines = [
            "- name: Deploy Traefik stack",
            "  hosts: traefik",
            "  tasks:",
            "    - name: Ensure Traefik compose is present",
            "      community.docker.docker_compose:",
            "        project_src: /opt/stacks/traefik",
            "        state: present",
        ]
        compose_lines = [
            "services:",
            "  traefik:",
            "    image: traefik:v3.2",
            "    networks:",
            "      - traefik",
            "      - socket-proxy",
            "networks:",
            "  traefik:",
            "  socket-proxy:",
        ]

    _write_yaml(playbook_path, playbook_lines)
    _write_yaml(compose_path, compose_lines)

    if with_issues:
        # Duplicate problem files to increase issue count and mimic multiple stacks
        for idx in range(1, 5):
            _write_yaml(tmp_path / "playbooks" / f"traefik_bad_{idx}.yml", playbook_lines)
        for idx in range(1, 5):
            extra_compose = tmp_path / "stacks" / f"traefik_bad_{idx}" / "docker-compose.yml"
            _write_yaml(extra_compose, compose_lines)

    return tmp_path


def _run_cli(args: list[str]) -> int:
    original = sys.argv
    try:
        sys.argv = ["analyze_iac.py", *args]
        return analyze_iac.main()
    finally:
        sys.argv = original


def test_cli_generates_json_report(tmp_path: Path) -> None:
    project = _create_project(tmp_path, with_issues=False)
    output = tmp_path / "report.json"

    exit_code = _run_cli(["--root", str(project), "--output", str(output), "--format", "json"])

    assert exit_code == 0
    data = json.loads(output.read_text(encoding="utf-8"))
    assert "scores" in data
    assert data["summary"]["total_issues"] == 0


def test_cli_text_output(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    project = _create_project(tmp_path, with_issues=False)
    exit_code = _run_cli(["--root", str(project), "--format", "text"])

    captured = capsys.readouterr()
    assert exit_code == 0
    assert "Infrastructure-as-Code Quality Report" in captured.out


def test_cli_failure_on_low_score(tmp_path: Path) -> None:
    project = _create_project(tmp_path, with_issues=True)
    output = tmp_path / "report.json"

    exit_code = _run_cli(["--root", str(project), "--output", str(output)])

    assert exit_code == 1
    data = json.loads(output.read_text(encoding="utf-8"))
    assert data["summary"]["total_issues"] > 0
