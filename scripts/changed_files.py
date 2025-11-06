#!/usr/bin/env python3
"""
Detect changed files and categorize them by type for selective CI/CD checks.
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Set


def run_command(cmd: List[str]) -> str:
    """Run a shell command and return output."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {' '.join(cmd)}", file=sys.stderr)
        print(f"Error: {e.stderr}", file=sys.stderr)
        return ""


def get_changed_files(base_ref: str = "origin/main") -> List[str]:
    """Get list of changed files compared to base ref."""
    # Try to get changed files from git
    output = run_command(["git", "diff", "--name-only", base_ref])
    if not output:
        # If no changes or not in git repo, return empty list
        return []
    return [f for f in output.split("\n") if f]


def categorize_files(files: List[str]) -> Dict[str, List[str]]:
    """Categorize files by type."""
    categories: Dict[str, List[str]] = {
        "yaml": [],
        "python": [],
        "shell": [],
        "dockerfile": [],
        "roles": [],
        "playbooks": [],
        "stacks": [],
        "molecule": [],
        "docs": [],
        "other": [],
    }

    for file in files:
        path = Path(file)

        # Check by extension
        if path.suffix in [".yml", ".yaml"]:
            categories["yaml"].append(file)

            # Check by directory
            if "playbooks/" in file:
                categories["playbooks"].append(file)
            elif "roles/" in file:
                categories["roles"].append(file)
            elif "stacks/" in file:
                categories["stacks"].append(file)
            elif "molecule/" in file:
                categories["molecule"].append(file)

        elif path.suffix == ".py":
            categories["python"].append(file)

        elif path.suffix == ".sh":
            categories["shell"].append(file)

        elif "Dockerfile" in path.name or path.name == "Containerfile":
            categories["dockerfile"].append(file)

        elif path.suffix in [".md", ".rst", ".txt"]:
            categories["docs"].append(file)

        else:
            categories["other"].append(file)

    return categories


def should_run_check(category: str, changed_categories: Set[str]) -> bool:
    """Determine if a check should run based on changed file categories."""
    # Always run if playbooks, roles, or molecule files changed
    always_run = {"playbooks", "roles", "molecule", "yaml"}
    if always_run & changed_categories:
        return True

    # Run specific checks for their categories
    check_mappings = {
        "lint_ansible": {"playbooks", "roles", "yaml"},
        "lint_yaml": {"yaml", "playbooks", "roles", "stacks", "molecule"},
        "lint_python": {"python"},
        "lint_shell": {"shell"},
        "lint_docker": {"dockerfile", "stacks"},
        "test_molecule": {"playbooks", "roles", "molecule", "yaml"},
    }

    return bool(check_mappings.get(category, set()) & changed_categories)


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Detect and categorize changed files for selective checks"
    )
    parser.add_argument(
        "--base",
        default="origin/main",
        help="Base reference to compare against (default: origin/main)",
    )
    parser.add_argument(
        "--format",
        choices=["json", "text", "github"],
        default="json",
        help="Output format (default: json)",
    )
    parser.add_argument(
        "--check",
        help="Check if a specific category has changes (returns exit code)",
    )

    args = parser.parse_args()

    changed_files = get_changed_files(args.base)
    categorized = categorize_files(changed_files)

    # Remove empty categories
    categorized = {k: v for k, v in categorized.items() if v}

    if args.check:
        # Return exit code based on whether check should run
        changed_categories = set(categorized.keys())
        should_run = should_run_check(args.check, changed_categories)
        sys.exit(0 if should_run else 1)

    if args.format == "json":
        output = {
            "total_files": len(changed_files),
            "categories": categorized,
            "changed_categories": list(categorized.keys()),
        }
        print(json.dumps(output, indent=2))

    elif args.format == "text":
        print(f"Total changed files: {len(changed_files)}")
        for category, files in categorized.items():
            print(f"\n{category.upper()} ({len(files)}):")
            for file in files:
                print(f"  - {file}")

    elif args.format == "github":
        # GitHub Actions output format
        print(f"total_files={len(changed_files)}")
        print(f"has_yaml={int('yaml' in categorized)}")
        print(f"has_python={int('python' in categorized)}")
        print(f"has_shell={int('shell' in categorized)}")
        print(f"has_playbooks={int('playbooks' in categorized)}")
        print(f"has_roles={int('roles' in categorized)}")
        print(f"has_stacks={int('stacks' in categorized)}")


if __name__ == "__main__":
    main()
