#!/usr/bin/env python3.12
"""Run HYDRA regression, coverage analysis, and one guarded repair attempt."""
from __future__ import annotations

import argparse
import difflib
import fnmatch
import hashlib
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

SIM = Path(__file__).resolve().parent
ROOT = SIM.parents[2]
SKIP = ("work", "cov_*", "ai_runs", "__pycache__", "*.log", "*.ucdb", "*.wlf", "*.dbg", "*.console")
SAFE_FIXES = (
    "src/hydra/*.sv",
    "uvm/uvm_transform/driver/*.sv",
    "uvm/uvm_transform/monitor/*.sv",
)


def ignored(_directory: str, names: list[str]) -> set[str]:
    return {name for name in names if any(fnmatch.fnmatch(name, pat) for pat in SKIP)}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_files(root: Path) -> dict[str, str]:
    result = {}
    for folder in (root / "src", root / "uvm"):
        for path in folder.rglob("*.sv"):
            if not any(fnmatch.fnmatch(part, pat) for part in path.relative_to(root).parts for pat in SKIP):
                result[str(path.relative_to(root))] = digest(path)
    return result


def invoke(cmd: list[str], cwd: Path, log: Path, *, prompt: str | None = None) -> int:
    with log.open("w") as out:
        try:
            result = subprocess.run(cmd, cwd=cwd, input=prompt, text=True,
                                    stdout=out, stderr=subprocess.STDOUT, timeout=3600)
            return result.returncode
        except (OSError, subprocess.TimeoutExpired) as exc:
            out.write(f"\nWorkflow command failed: {exc}\n")
            return 124


def run_checks(stage_root: Path, run_dir: Path, tag: str) -> tuple[bool, Path | None]:
    sim = stage_root / "uvm/uvm_integration/sim"
    print(f"{tag}: clean compile")
    if invoke(["bash", "build_clean.sh"], sim, run_dir / f"{tag}_compile.log"):
        return False, None
    print(f"{tag}: regression and coverage")
    before = set(sim.glob("cov_*"))
    rc = invoke(["bash", "run_integration_suite.sh"], sim, run_dir / f"{tag}_regression.log")
    cov_dirs = sorted((p for p in sim.glob("cov_*") if p not in before),
                      key=lambda p: p.stat().st_mtime)
    cov = cov_dirs[-1] if cov_dirs else None
    if rc:
        return False, cov
    required = ("functional_coverage_report.txt", "code_coverage_report.txt", "merged.ucdb")
    return bool(cov and all((cov / name).is_file() for name in required)), cov


def codex(prompt: str, cwd: Path, output: Path, log: Path, sandbox: str) -> int:
    return invoke(["codex", "exec", "--sandbox", sandbox, "--skip-git-repo-check",
                   "--cd", str(cwd), "--output-last-message", str(output), prompt], cwd, log)


def analyze(run_dir: Path, stage_root: Path, cov: Path, tag: str, status: str) -> bool:
    prompt = (
        "Analyze the HYDRA UVM regression and coverage artifacts. Read the exact files named below. "
        "Write a concise English Markdown report with: run status and case counts; functional and RTL code "
        "coverage percentages only if explicitly supported by the reports; notable uncovered RTL branches "
        "with file/line evidence; any failures, likely cause, and the next concrete check. "
        "Do not edit files. Do not claim a branch is unreachable without RTL evidence. "
        f"Status: {status}. Regression log: {run_dir / (tag + '_regression.log')}. "
        f"Compile log: {run_dir / (tag + '_compile.log')}. "
        f"Functional report: {cov / 'functional_coverage_report.txt'}. "
        f"Code report: {cov / 'code_coverage_report.txt'}."
    )
    rc = codex(prompt, stage_root, run_dir / "analysis.md", run_dir / "ai_analysis.log", "read-only")
    return rc == 0 and (run_dir / "analysis.md").is_file()


def make_patch(original: Path, staged: Path, changed: list[str], output: Path) -> None:
    with output.open("w") as patch:
        for rel in changed:
            before = (original / rel).read_text().splitlines(keepends=True)
            after = (staged / rel).read_text().splitlines(keepends=True)
            patch.writelines(difflib.unified_diff(before, after, fromfile=f"a/{rel}", tofile=f"b/{rel}"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-apply", action="store_true", help="Validate AI changes without copying them to the source tree")
    args = parser.parse_args()
    run_dir = SIM / "ai_runs" / datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir.mkdir(parents=True, exist_ok=False)
    summary = ["# HYDRA AI workflow", "", f"Run directory: {run_dir}", ""]

    first_ok, first_cov = run_checks(ROOT, run_dir, "initial")
    if first_ok:
        assert first_cov is not None
        summary.append("- Clean compile and full regression: PASS")
        summary.append(f"- Coverage directory: {first_cov}")
        ai_ok = analyze(run_dir, ROOT, first_cov, "initial", "PASS")
        summary.append(f"- Codex coverage analysis: {'PASS' if ai_ok else 'FAILED (see ai_analysis.log)'}")
        (run_dir / "summary.md").write_text("\n".join(summary) + "\n")
        print(f"Coverage: {first_cov}")
        print(f"Analysis: {run_dir}")
        return 0 if ai_ok else 1

    summary.append("- Initial compile or regression: FAIL")
    print("Initial checks failed; asking Codex for one temporary repair attempt")
    with tempfile.TemporaryDirectory(prefix="hydra_ai_stage_") as temporary:
        stage = Path(temporary)
        shutil.copytree(ROOT / "src", stage / "src", ignore=ignored)
        shutil.copytree(ROOT / "uvm", stage / "uvm", ignore=ignored)
        baseline = source_files(stage)
        repair_prompt = (
            "Debug this HYDRA UVM compile/regression failure using the logs at "
            f"{run_dir / 'initial_compile.log'} and {run_dir / 'initial_regression.log'}. "
            "Inspect source in the current temporary tree. Make the smallest justified source fix. "
            "Do not change tests, assertions, scoreboards, coverage definitions, build scripts, or regression scripts. "
            "Do not weaken checks or invent passing results. Explain the root cause and edited files in English."
        )
        rc = codex(repair_prompt, stage, run_dir / "repair_notes.md", run_dir / "ai_repair.log", "workspace-write")
        after = source_files(stage)
        changed = sorted(rel for rel in set(baseline) | set(after) if baseline.get(rel) != after.get(rel))
        if changed:
            make_patch(ROOT, stage, changed, run_dir / "repair.patch")
        safe = bool(changed) and all(any(fnmatch.fnmatch(rel, pat) for pat in SAFE_FIXES) for rel in changed)
        summary.append(f"- Codex repair command: {'PASS' if rc == 0 else 'FAILED'}")
        summary.append(f"- Modified source files: {', '.join(changed) if changed else 'none'}")
        if rc or not safe:
            summary.append("- Repair not applied: no eligible source-only patch")
            (run_dir / "summary.md").write_text("\n".join(summary) + "\n")
            print(f"Repair needs review: {run_dir}")
            return 1

        verified, repaired_cov = run_checks(stage, run_dir, "repaired")
        summary.append(f"- Temporary clean compile and full regression: {'PASS' if verified else 'FAIL'}")
        if not verified:
            (run_dir / "summary.md").write_text("\n".join(summary) + "\n")
            print(f"Repair failed validation: {run_dir}")
            return 1
        assert repaired_cov is not None
        analysis_root = stage
        analysis_cov = repaired_cov
        if args.no_apply:
            saved_cov = SIM / repaired_cov.name
            if saved_cov.exists():
                saved_cov = SIM / f"{repaired_cov.name}_repaired_{run_dir.name}"
            shutil.move(str(repaired_cov), str(saved_cov))
            analysis_cov = saved_cov
            summary.append("- Validated patch saved; source tree unchanged (--no-apply)")
        else:
            backup = run_dir / "backup"
            for rel in changed:
                (backup / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / rel, backup / rel)
                shutil.copy2(stage / rel, ROOT / rel)
            live_ok, live_cov = run_checks(ROOT, run_dir, "live")
            if not live_ok:
                for rel in changed:
                    shutil.copy2(backup / rel, ROOT / rel)
                summary.append("- Live validation: FAIL; original source restored")
                (run_dir / "summary.md").write_text("\n".join(summary) + "\n")
                print(f"Live validation failed; source restored: {run_dir}")
                return 1
            assert live_cov is not None
            analysis_root = ROOT
            analysis_cov = live_cov
            summary.append("- Verified source-only repair applied; live regression: PASS")
        summary.append(f"- Coverage directory: {analysis_cov}")
        ai_ok = analyze(run_dir, analysis_root, analysis_cov, "repaired", "PASS after repair")
        summary.append(f"- Codex coverage analysis: {'PASS' if ai_ok else 'FAILED (see ai_analysis.log)'}")
        (run_dir / "summary.md").write_text("\n".join(summary) + "\n")
        print(f"Coverage: {analysis_cov}")
        print(f"Analysis: {run_dir}")
        return 0 if ai_ok else 1


if __name__ == "__main__":
    sys.exit(main())
