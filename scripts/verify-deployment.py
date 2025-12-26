#!/usr/bin/env python3
"""Deployment verification helper for Conxian Protocol.

This script coordinates the standard pre-deployment checks:
1. Runs Clarinet checks to confirm contracts compile against the Nakamoto toolchain.
2. Runs the selected npm/vitest suite to ensure JS tooling and integration tests pass.
3. Emits a structured summary plus per-step log files for later auditability.

Usage examples
--------------
python scripts/verify-deployment.py \
    --project-root . \
    --clarinet-command "python -m clarinet check" \
    --npm-script test:core

python scripts/verify-deployment.py --skip-npm
"""
from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import shlex
import subprocess
import sys
from dataclasses import dataclass
from typing import List, Optional


@dataclass
class StepResult:
    name: str
    command: str
    returncode: Optional[int]
    stdout: str
    stderr: str
    duration: float
    error: Optional[str] = None

    @property
    def success(self) -> bool:
        return self.returncode == 0 and self.error is None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Conxian deployment verification helper")
    parser.add_argument(
        "--project-root",
        type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parents[1],
        help="Root directory of the Conxian repository (default: repo root)",
    )
    parser.add_argument(
        "--clarinet-command",
        default="clarinet check",
        help="Command used to run Clarinet checks (default: 'clarinet check')",
    )
    parser.add_argument(
        "--clarinet-timeout",
        type=int,
        default=600,
        help="Clarinet check timeout in seconds (default: 600)",
    )
    parser.add_argument(
        "--npm-script",
        default="test",
        help="npm script to run for JS/Vitest checks (default: test)",
    )
    parser.add_argument(
        "--npm-timeout",
        type=int,
        default=1200,
        help="npm test timeout in seconds (default: 1200)",
    )
    parser.add_argument(
        "--skip-clarinet",
        action="store_true",
        help="Skip the Clarinet check step",
    )
    parser.add_argument(
        "--skip-npm",
        action="store_true",
        help="Skip the npm test step",
    )
    parser.add_argument(
        "--log-dir",
        type=pathlib.Path,
        default=None,
        help="Optional directory for log output (default: project-root/logs/deployment-verification)",
    )
    return parser.parse_args()


def ensure_log_dir(base_dir: pathlib.Path) -> pathlib.Path:
    timestamp = dt.datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    target = base_dir / timestamp
    target.mkdir(parents=True, exist_ok=True)
    return target


def run_step(name: str, command: str, cwd: pathlib.Path, timeout: int) -> StepResult:
    started = dt.datetime.utcnow()
    try:
        completed = subprocess.run(
            shlex.split(command),
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        duration = (dt.datetime.utcnow() - started).total_seconds()
        return StepResult(
            name=name,
            command=command,
            returncode=completed.returncode,
            stdout=completed.stdout,
            stderr=completed.stderr,
            duration=duration,
        )
    except FileNotFoundError as exc:
        duration = (dt.datetime.utcnow() - started).total_seconds()
        return StepResult(
            name=name,
            command=command,
            returncode=None,
            stdout="",
            stderr="",
            duration=duration,
            error=f"Command not found: {exc}",
        )
    except subprocess.TimeoutExpired as exc:
        duration = (dt.datetime.utcnow() - started).total_seconds()
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        return StepResult(
            name=name,
            command=command,
            returncode=None,
            stdout=stdout,
            stderr=stderr,
            duration=duration,
            error=f"Timeout after {timeout}s",
        )


def write_log(result: StepResult, log_dir: pathlib.Path) -> None:
    safe_name = result.name.lower().replace(" ", "-")
    log_file = log_dir / f"{safe_name}.log"
    with log_file.open("w", encoding="utf-8") as fh:
        fh.write(f"# {result.name}\n")
        fh.write(f"Command: {result.command}\n")
        fh.write(f"Return code: {result.returncode}\n")
        if result.error:
            fh.write(f"Error: {result.error}\n")
        fh.write("\n## STDOUT\n")
        fh.write(result.stdout or "<empty>\n")
        fh.write("\n## STDERR\n")
        fh.write(result.stderr or "<empty>\n")


def print_summary(results: List[StepResult], log_dir: pathlib.Path) -> None:
    print("\n================ Deployment Verification Summary ================")
    print(f"Log directory: {log_dir}")
    any_fail = False
    for res in results:
        status = "PASS" if res.success else "FAIL"
        if not res.success:
            any_fail = True
        detail = res.error or res.stderr.strip().splitlines()[0] if res.stderr else ""
        print(f"- {res.name:<20} [{status}] ({res.duration:.1f}s)")
        if detail:
            print(f"    -> {detail}")
    print("================================================================\n")
    if any_fail:
        print("At least one step failed. Review logs before deploying.", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    args = parse_args()
    project_root = args.project_root.resolve()
    if not project_root.exists():
        print(f"Project root does not exist: {project_root}", file=sys.stderr)
        sys.exit(2)

    default_log_dir = args.log_dir or (project_root / "logs" / "deployment-verification")
    log_dir = ensure_log_dir(default_log_dir)

    results: List[StepResult] = []

    if not args.skip_clarinet:
        results.append(
            run_step(
                name="Clarinet Check",
                command=args.clarinet_command,
                cwd=project_root,
                timeout=args.clarinet_timeout,
            )
        )
    else:
        print("[warn] Skipping Clarinet check as requested")

    if not args.skip_npm:
        npm_cmd = f"npm run {args.npm_script}" if args.npm_script != "test" else "npm test"
        results.append(
            run_step(
                name="NPM Tests",
                command=npm_cmd,
                cwd=project_root,
                timeout=args.npm_timeout,
            )
        )
    else:
        print("[warn] Skipping npm tests as requested")

    for res in results:
        write_log(res, log_dir)

    if results:
        print_summary(results, log_dir)
    else:
        print("No steps executed (all skipped). Nothing to do.")


if __name__ == "__main__":
    main()
