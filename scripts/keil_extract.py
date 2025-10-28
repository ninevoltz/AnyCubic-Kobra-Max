#!/usr/bin/env python3
"""
Extract build metadata from the Keil uVision project for use with GCC builds.

Usage:
    python keil_extract.py <uvprojx-path> sources
    python keil_extract.py <uvprojx-path> includes

Outputs newline-separated relative paths.
"""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


VALID_SOURCE_EXTS = {".c", ".cc", ".cpp", ".cxx", ".C", ".s", ".S"}


def normalize_path(base: Path, raw: str) -> Path:
    """Convert a Keil-style path into a repository-relative POSIX path."""
    raw = raw.replace("\\", "/")
    candidate = (base / raw)
    candidate = _case_correct(candidate)
    candidate = candidate.resolve()
    repo_root = Path(__file__).resolve().parents[1]
    try:
        return candidate.relative_to(repo_root)
    except ValueError as exc:
        raise SystemExit(f"path {candidate} is outside repository") from exc


def _case_correct(path: Path) -> Path:
    """
    Adjust path component casing to match the filesystem when the incoming
    path uses a different case (common in Keil projects created on Windows).
    """
    if path.exists():
        return path

    parts = list(path.parts)
    if not parts:
        return path

    # Determine starting point (anchor or current directory)
    if path.is_absolute():
        corrected = Path(parts[0])
        idx = 1
    else:
        corrected = Path()
        idx = 0

    for part in parts[idx:]:
        if part in ("", "."):
            continue
        if part == "..":
            corrected = corrected.parent
            continue

        try:
            entries = {p.name.lower(): p for p in corrected.iterdir()}
        except FileNotFoundError:
            corrected = corrected / part
        else:
            corrected = entries.get(part.lower(), corrected / part)
    return corrected


def extract_sources(root: ET.Element, project_dir: Path) -> list[Path]:
    """Return normalized source file paths."""
    sources: list[Path] = []
    skip_names = {"startup_hc32f46x.s"}  # Keil-only startup

    for file_path in root.iter("FilePath"):
        text = file_path.text
        if not text:
            continue
        norm = normalize_path(project_dir, text)
        if norm.name in skip_names:
            continue
        if norm.suffix in VALID_SOURCE_EXTS and norm.is_file():
            sources.append(norm)

    # Add the GCC-compatible startup file
    gcc_startup = Path("source/main/hdsc32core/startup_hc32f46x_gcc.c")
    sources.append(gcc_startup)

    # Drop duplicates while keeping order
    seen: set[Path] = set()
    unique_sources: list[Path] = []
    for src in sources:
        if src not in seen:
            seen.add(src)
            unique_sources.append(src)
    return unique_sources


def extract_includes(root: ET.Element, project_dir: Path) -> list[Path]:
    """Return normalized include directories."""
    include_dirs: list[Path] = []
    for include_path in root.iter("IncludePath"):
        text = include_path.text or ""
        for entry in filter(None, (part.strip() for part in text.split(";"))):
            norm = normalize_path(project_dir, entry)
            if norm.is_dir():
                include_dirs.append(norm)

    # Always include the project root for headers referenced with relative paths
    include_dirs.append(Path("."))

    seen: set[Path] = set()
    unique_includes: list[Path] = []
    for inc in include_dirs:
        if inc not in seen:
            seen.add(inc)
            unique_includes.append(inc)
    return unique_includes


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[2] not in {"sources", "includes"}:
        raise SystemExit("usage: keil_extract.py <uvprojx> <sources|includes>")

    uvprojx = Path(sys.argv[1]).resolve()
    if not uvprojx.is_file():
        raise SystemExit(f"project file not found: {uvprojx}")

    root = ET.parse(uvprojx).getroot()
    project_dir = uvprojx.parent

    if sys.argv[2] == "sources":
        results = extract_sources(root, project_dir)
    else:
        results = extract_includes(root, project_dir)

    sys.stdout.write("\n".join(str(path.as_posix()) for path in results))
