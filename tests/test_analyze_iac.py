"""Unit tests for the IaC analyzer logic."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Iterable

import pytest

from scripts.analyze_iac import IaCAnalyzer


pytestmark = pytest.mark.unit


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.strip() + "\n", encoding="utf-8")


def _write_yaml(path: Path, lines: Iterable[str]) -> None:
    _write_text(path, "\n".join(lines))


def test_get_timestamp_returns_utc_iso8601() -> None:
    timestamp = IaCAnalyzer._get_timestamp()
    assert timestamp.endswith("Z")
    cleaned = timestamp[:-1] if timestamp.endswith("Z") else timestamp
    parsed = datetime.fromisoformat(cleaned)
    assert parsed.tzinfo is not None


def test_analyze_project_collects_playbook_and_compose_issues(tmp_path: Path) -> None:
    playbook_path = tmp_path / "playbooks" / "problem.yml"
    _write_yaml(
        playbook_path,
        [
            "- name: Bootstrap Traefik stack",
            "  hosts: traefik",
            "  tasks:",
            "    - name: Pull Traefik image",
            "      community.docker.docker_image:",
            "        name: traefik:v3.2",
            "    - name: Refresh package cache",
            "      shell: apt update",
            "    - shell: systemctl restart traefik",
        ],
    )

    compose_path = tmp_path / "stacks" / "app" / "docker-compose.yml"
    _write_yaml(
        compose_path,
        [
            "services:",
            "  traefik:",
            "    image: traefik:v3.2",
            "    volumes:",
            "      - /var/run/docker.sock:/var/run/docker.sock",
            "    networks:",
            "      - socket-proxy",
            "      - traefik",
            "  traefik-oauth2-proxy:",
            "    image: quay.io/oauth2-proxy/oauth2-proxy:v7.6.0",
            "    network_mode: host",
            "networks:",
            "  traefik:",
            "  socket-proxy:",
        ],
    )

    analyzer = IaCAnalyzer()
    report = analyzer.analyze_project(tmp_path)

    assert report.files_analyzed == 2
    categories = {issue.category for issue in report.issues}
    assert {"idempotence", "standards", "atomicity", "maintainability"}.issubset(categories)
    assert report.summary["total_issues"] == len(report.issues)
    assert report.overall_score < 100


def test_add_issue_records_fix_suggestion() -> None:
    analyzer = IaCAnalyzer()
    issue_path = Path("playbooks/example.yml")
    analyzer._add_issue(issue_path, 3, "warning", "maintainability", "message", "fix")

    assert len(analyzer.issues) == 1
    issue = analyzer.issues[0]
    assert issue.file.endswith("playbooks/example.yml")
    assert issue.fix_suggestion == "fix"


def test_compose_security_checks_detect_privileged_and_host(tmp_path: Path) -> None:
    compose_path = tmp_path / "stacks" / "app" / "docker-compose.yml"
    _write_yaml(
        compose_path,
        [
            "services:",
            "  traefik:",
            "    image: traefik:v3.2",
            "    privileged: true",
            "  traefik-oauth2-proxy:",
            "    image: quay.io/oauth2-proxy/oauth2-proxy:v7.6.0",
            "    network_mode: host",
        ],
    )

    analyzer = IaCAnalyzer()
    analyzer._analyze_compose_file(compose_path)

    assert any(issue.message.endswith("privileged mode") for issue in analyzer.issues)
    assert any("host network mode" in issue.message for issue in analyzer.issues)


def test_generate_summary_counts_by_severity(tmp_path: Path) -> None:
    playbook_path = tmp_path / "playbooks" / "sample.yml"
    _write_yaml(
        playbook_path,
        [
            "- name: Traefik deployment",
            "  hosts: traefik",
            "  tasks:",
            "    - name: Deploy Traefik stack",
            "      community.docker.docker_compose:",
            "        project_src: /opt/stacks/traefik",
            "        state: present",
        ],
    )

    analyzer = IaCAnalyzer()
    analyzer._add_issue(playbook_path, 1, "error", "standards", "error msg")
    analyzer._add_issue(playbook_path, 2, "warning", "maintainability", "warn msg")
    analyzer._add_issue(playbook_path, 3, "info", "atomicity", "info msg")

    analyzer._generate_summary()
    summary = analyzer.report.summary

    assert summary["by_severity"]["error"] == 1
    assert summary["by_severity"]["warning"] == 1
    assert summary["by_severity"]["info"] == 1
    assert summary["total_issues"] == 3


def test_analyzer_serializes_report_to_json(tmp_path: Path) -> None:
    playbook_path = tmp_path / "playbooks" / "ok.yml"
    _write_yaml(
        playbook_path,
        [
            "- name: Deploy Traefik",
            "  hosts: traefik",
            "  tasks:",
            "    - name: Ensure Traefik compose is present",
            "      community.docker.docker_compose:",
            "        project_src: /opt/stacks/traefik",
            "        state: present",
        ],
    )

    analyzer = IaCAnalyzer()
    report = analyzer.analyze_project(tmp_path)

    output = tmp_path / "report.json"
    with open(output, "w", encoding="utf-8") as handle:
        json.dump(report.summary, handle)

    data = json.loads(output.read_text(encoding="utf-8"))
    assert "total_issues" in data
