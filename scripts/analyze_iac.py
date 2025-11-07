#!/usr/bin/env python3
"""
Infrastructure-as-Code Quality Analysis Script

Performs static analysis on Ansible playbooks and Docker Compose files to assess:
- Atomicity: Are tasks properly scoped and independent?
- Idempotence: Can playbooks be run multiple times safely?
- Maintainability: Is the code well-structured and documented?
- Custom Standards: Project-specific rules enforcement
"""

import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

import yaml


@dataclass
class Issue:
    """Represents a quality issue found during analysis."""

    file: str
    line: int
    severity: str  # 'error', 'warning', 'info'
    category: str  # 'atomicity', 'idempotence', 'maintainability', 'standards'
    message: str
    fix_suggestion: Optional[str] = None


@dataclass
class AnalysisReport:
    """Complete analysis report with scores and issues."""

    timestamp: str
    atomicity_score: float = 100.0
    idempotence_score: float = 100.0
    maintainability_score: float = 100.0
    standards_score: float = 100.0
    overall_score: float = 100.0
    issues: List[Issue] = field(default_factory=list)
    files_analyzed: int = 0
    summary: Dict[str, int] = field(default_factory=dict)


class IaCAnalyzer:
    """Main analyzer class."""

    def __init__(self):
        self.report = AnalysisReport(timestamp=self._get_timestamp())
        self.issues: List[Issue] = []

    @staticmethod
    def _get_timestamp() -> str:
        """Get current UTC timestamp."""
        from datetime import datetime, UTC

        return datetime.now(UTC).isoformat() + "Z"

    def analyze_project(self, root_path: Path) -> AnalysisReport:
        """Analyze entire project."""
        print("Analyzing Infrastructure-as-Code project...")

        # Analyze playbooks
        playbook_dir = root_path / "playbooks"
        if playbook_dir.exists():
            for playbook_file in playbook_dir.rglob("*.yml"):
                self._analyze_playbook(playbook_file)
                self.report.files_analyzed += 1

        # Analyze Docker Compose files
        stacks_dir = root_path / "stacks"
        if stacks_dir.exists():
            for compose_file in stacks_dir.rglob("docker-compose.yml"):
                self._analyze_compose_file(compose_file)
                self.report.files_analyzed += 1

        # Calculate scores
        self._calculate_scores()

        # Generate summary
        self._generate_summary()

        self.report.issues = self.issues
        return self.report

    def _analyze_playbook(self, playbook_path: Path):
        """Analyze an Ansible playbook."""
        try:
            with open(playbook_path, encoding="utf-8") as f:
                content = f.read()
                data = yaml.safe_load(content)

            if not data:
                return

            # Check for list of plays
            if not isinstance(data, list):
                self._add_issue(
                    playbook_path,
                    1,
                    "error",
                    "maintainability",
                    "Playbook must be a list of plays",
                )
                return

            for play_idx, play in enumerate(data):
                if not isinstance(play, dict):
                    continue

                # Check for play name
                if "name" not in play:
                    self._add_issue(
                        playbook_path,
                        play_idx + 1,
                        "warning",
                        "maintainability",
                        "Play should have a descriptive name",
                        "Add 'name: <description>' to the play",
                    )

                # Check tasks
                if "tasks" in play:
                    self._analyze_tasks(playbook_path, play["tasks"])

                # Check idempotence indicators
                self._check_idempotence(playbook_path, play)

        except yaml.YAMLError as e:
            self._add_issue(
                playbook_path,
                1,
                "error",
                "maintainability",
                f"YAML parsing error: {e}",
            )
        except Exception as e:
            print(f"Error analyzing {playbook_path}: {e}", file=sys.stderr)

    def _analyze_tasks(self, playbook_path: Path, tasks: List):
        """Analyze playbook tasks."""
        if not isinstance(tasks, list):
            return

        for task_idx, task in enumerate(tasks):
            if not isinstance(task, dict):
                continue

            # Check for task names
            if "name" not in task:
                self._add_issue(
                    playbook_path,
                    task_idx + 1,
                    "warning",
                    "maintainability",
                    "Task should have a descriptive name",
                    "Add 'name: <description>' to the task",
                )

            # Check for shell/command modules without changed_when
            if any(mod in task for mod in ["shell", "command", "raw"]):
                if "changed_when" not in task:
                    self._add_issue(
                        playbook_path,
                        task_idx + 1,
                        "warning",
                        "idempotence",
                        "shell/command/raw should define 'changed_when' for idempotence",
                        "Add 'changed_when: <condition>' to indicate when task makes changes",
                    )

            # Check for proper module usage over shell
            if "shell" in task or "command" in task:
                task_str = str(task)
                if any(keyword in task_str for keyword in ["apt", "yum", "dnf", "pip", "systemctl", "service"]):
                    self._add_issue(
                        playbook_path,
                        task_idx + 1,
                        "info",
                        "atomicity",
                        "Consider using dedicated Ansible module instead of shell/command",
                        "Use apt, package, pip, systemd, or service modules",
                    )

    def _check_idempotence(self, playbook_path: Path, play: Dict):
        """Check for idempotence best practices."""
        # Check for state parameters
        if "tasks" in play:
            for task in play["tasks"]:
                if not isinstance(task, dict):
                    continue

                # Check for state in package/service tasks
                for module in ["apt", "yum", "dnf", "package", "service", "systemd"]:
                    if module in task:
                        if isinstance(task[module], dict) and "state" not in task[module]:
                            self._add_issue(
                                playbook_path,
                                1,
                                "info",
                                "idempotence",
                                f"{module} task should explicitly set 'state' parameter",
                                "Add 'state: present' or 'state: started' etc.",
                            )

    def _analyze_compose_file(self, compose_path: Path):
        """Analyze a Docker Compose file."""
        try:
            with open(compose_path, encoding="utf-8") as f:
                data = yaml.safe_load(f)

            if not data:
                return

            # Check custom standard: Only root orchestrator can define networks
            is_root_orchestrator = compose_path.name == "docker-compose.yml" and compose_path.parent.name == "stacks"

            if "networks" in data:
                for network_name, network_config in data["networks"].items():
                    if isinstance(network_config, dict) and not network_config.get("external", False):
                        if not is_root_orchestrator:
                            self._add_issue(
                                compose_path,
                                1,
                                "error",
                                "standards",
                                f"Only root orchestrator can define networks (found: {network_name})",
                                "Use 'external: true' or move network definition to root orchestrator",
                            )

            # Check custom standard: Docker socket access via proxy
            if "services" in data:
                for service_name, service_config in data["services"].items():
                    if not isinstance(service_config, dict):
                        continue

                    volumes = service_config.get("volumes", [])
                    for volume in volumes:
                        if isinstance(volume, str) and "/var/run/docker.sock" in volume:
                            # Exception for docker-socket-proxy itself
                            if service_name != "docker-socket-proxy":
                                self._add_issue(
                                    compose_path,
                                    1,
                                    "error",
                                    "standards",
                                    f"Service '{service_name}' accesses Docker socket directly",
                                    "Use docker-socket-proxy service instead: DOCKER_HOST=tcp://docker-socket-proxy:2375",
                                )

            # Check for security best practices
            self._check_compose_security(compose_path, data)

        except yaml.YAMLError as e:
            self._add_issue(
                compose_path,
                1,
                "error",
                "maintainability",
                f"YAML parsing error: {e}",
            )
        except Exception as e:
            print(f"Error analyzing {compose_path}: {e}", file=sys.stderr)

    def _check_compose_security(self, compose_path: Path, data: Dict):
        """Check Docker Compose security best practices."""
        if "services" not in data:
            return

        for service_name, service_config in data["services"].items():
            if not isinstance(service_config, dict):
                continue

            # Check for privileged mode
            if service_config.get("privileged", False):
                self._add_issue(
                    compose_path,
                    1,
                    "warning",
                    "standards",
                    f"Service '{service_name}' uses privileged mode",
                    "Avoid privileged mode; use specific capabilities instead",
                )

            # Check for host network mode
            if service_config.get("network_mode") == "host":
                self._add_issue(
                    compose_path,
                    1,
                    "warning",
                    "standards",
                    f"Service '{service_name}' uses host network mode",
                    "Use bridge networking and port mappings instead",
                )

    def _add_issue(
        self,
        file: Path,
        line: int,
        severity: str,
        category: str,
        message: str,
        fix_suggestion: Optional[str] = None,
    ):
        """Add an issue to the report."""
        issue = Issue(
            file=str(file),
            line=line,
            severity=severity,
            category=category,
            message=message,
            fix_suggestion=fix_suggestion,
        )
        self.issues.append(issue)

    def _calculate_scores(self):
        """Calculate quality scores based on issues found."""
        category_issues = {
            "atomicity": [],
            "idempotence": [],
            "maintainability": [],
            "standards": [],
        }

        for issue in self.issues:
            category_issues[issue.category].append(issue)

        # Calculate scores (deduct points for issues)
        def calc_score(issues: List[Issue]) -> float:
            score = 100.0
            for issue in issues:
                if issue.severity == "error":
                    score -= 10
                elif issue.severity == "warning":
                    score -= 5
                elif issue.severity == "info":
                    score -= 2
            return max(0.0, score)

        self.report.atomicity_score = calc_score(category_issues["atomicity"])
        self.report.idempotence_score = calc_score(category_issues["idempotence"])
        self.report.maintainability_score = calc_score(category_issues["maintainability"])
        self.report.standards_score = calc_score(category_issues["standards"])

        # Overall score is weighted average
        self.report.overall_score = (
            self.report.atomicity_score * 0.25
            + self.report.idempotence_score * 0.30
            + self.report.maintainability_score * 0.20
            + self.report.standards_score * 0.25
        )

    def _generate_summary(self):
        """Generate summary statistics."""
        severity_counts = {"error": 0, "warning": 0, "info": 0}
        category_counts = {"atomicity": 0, "idempotence": 0, "maintainability": 0, "standards": 0}

        for issue in self.issues:
            severity_counts[issue.severity] += 1
            category_counts[issue.category] += 1

        self.report.summary = {
            "total_issues": len(self.issues),
            "by_severity": severity_counts,
            "by_category": category_counts,
        }


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Analyze Infrastructure-as-Code quality")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("."),
        help="Root directory of the project",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("tests/artifacts/quality_report.json"),
        help="Output file for JSON report",
    )
    parser.add_argument(
        "--format",
        choices=["json", "text", "markdown"],
        default="json",
        help="Output format",
    )

    args = parser.parse_args()

    analyzer = IaCAnalyzer()
    report = analyzer.analyze_project(args.root)

    if args.format == "json":
        # Write JSON report
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "timestamp": report.timestamp,
                    "scores": {
                        "atomicity": report.atomicity_score,
                        "idempotence": report.idempotence_score,
                        "maintainability": report.maintainability_score,
                        "standards": report.standards_score,
                        "overall": report.overall_score,
                    },
                    "summary": report.summary,
                    "files_analyzed": report.files_analyzed,
                    "issues": [
                        {
                            "file": issue.file,
                            "line": issue.line,
                            "severity": issue.severity,
                            "category": issue.category,
                            "message": issue.message,
                            "fix_suggestion": issue.fix_suggestion,
                        }
                        for issue in report.issues
                    ],
                },
                f,
                indent=2,
            )
        print(f"\n✓ JSON report written to {args.output}")

    elif args.format == "text":
        print(f"\n{'=' * 80}")
        print("Infrastructure-as-Code Quality Report")
        print(f"{'=' * 80}\n")
        print(f"Files Analyzed: {report.files_analyzed}")
        print(f"Total Issues: {report.summary['total_issues']}\n")
        print("Scores:")
        print(f"  Atomicity:      {report.atomicity_score:.1f}/100")
        print(f"  Idempotence:    {report.idempotence_score:.1f}/100")
        print(f"  Maintainability: {report.maintainability_score:.1f}/100")
        print(f"  Standards:      {report.standards_score:.1f}/100")
        print(f"  Overall:        {report.overall_score:.1f}/100\n")

        if report.issues:
            print("Issues Found:")
            for issue in sorted(report.issues, key=lambda x: (x.severity, x.file)):
                print(f"\n[{issue.severity.upper()}] {issue.file}:{issue.line}")
                print(f"  Category: {issue.category}")
                print(f"  Message: {issue.message}")
                if issue.fix_suggestion:
                    print(f"  Fix: {issue.fix_suggestion}")

    return 0 if report.overall_score >= 80 else 1


if __name__ == "__main__":
    sys.exit(main())
