#!/usr/bin/env python3

import argparse
import datetime as dt
import json
import shutil
from pathlib import Path
from typing import Any


def default_app_support_dir() -> Path:
    return Path.home() / "Library" / "Application Support" / "cmux-atlas"


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def resolve_organization_paths(org_dir: Path, latest: int, org_names: list[str]) -> list[Path]:
    if org_names:
        resolved: list[Path] = []
        for raw_name in org_names:
            candidate = Path(raw_name).expanduser()
            if candidate.is_file():
                resolved.append(candidate)
                continue

            basename = raw_name if raw_name.endswith(".json") else f"{raw_name}.json"
            candidate = org_dir / basename
            if candidate.is_file():
                resolved.append(candidate)
                continue

            raise FileNotFoundError(f"organization snapshot not found: {raw_name}")
        return resolved

    snapshots = sorted(
        org_dir.glob("*.json"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return snapshots[:latest]


def make_snapshot(
    current_session: dict[str, Any] | None,
    workspace_snapshots: list[dict[str, Any]],
) -> dict[str, Any]:
    if current_session and current_session.get("windows"):
        base_window = current_session["windows"][0]
        frame = base_window.get("frame")
        display = base_window.get("display")
        sidebar = base_window.get("sidebar", {"isVisible": True, "selection": "tabs", "width": 320})
    else:
        frame = None
        display = None
        sidebar = {"isVisible": True, "selection": "tabs", "width": 320}

    return {
        "version": 1,
        "createdAt": dt.datetime.now().timestamp(),
        "windows": [
            {
                "frame": frame,
                "display": display,
                "sidebar": sidebar,
                "tabManager": {
                    "selectedWorkspaceIndex": 0 if workspace_snapshots else None,
                    "workspaces": workspace_snapshots,
                },
            }
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Rebuild the Atlas release session from saved workspace organization snapshots."
    )
    parser.add_argument(
        "--session-file",
        type=Path,
        default=default_app_support_dir() / "session-com.atlascodes.cmux-atlas.json",
    )
    parser.add_argument(
        "--org-dir",
        type=Path,
        default=default_app_support_dir() / "workspace-organizations",
    )
    parser.add_argument(
        "--latest",
        type=int,
        default=5,
        help="Use the N most recent organization snapshots when --org is not provided.",
    )
    parser.add_argument(
        "--org",
        action="append",
        default=[],
        help="Specific organization snapshot file or basename to include. Repeatable.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the selected organization snapshots without writing the session file.",
    )
    args = parser.parse_args()

    if not args.org_dir.is_dir():
        raise SystemExit(f"organization directory not found: {args.org_dir}")

    selected_paths = resolve_organization_paths(args.org_dir, args.latest, args.org)
    if not selected_paths:
        raise SystemExit("no organization snapshots selected")

    organizations: list[dict[str, Any]] = []
    for path in selected_paths:
        payload = load_json(path)
        snapshot = payload.get("snapshot")
        if not isinstance(snapshot, dict):
            raise SystemExit(f"organization snapshot missing 'snapshot': {path}")
        organizations.append(payload)

    print("Selected organization snapshots:")
    for payload, path in zip(organizations, selected_paths):
        snapshot = payload["snapshot"]
        panels = snapshot.get("panels", [])
        print(
            f"  - {payload.get('name', path.stem)} "
            f"({len(panels)} panels) [{path.name}]"
        )

    if args.dry_run:
        return 0

    current_session = load_json(args.session_file) if args.session_file.is_file() else None
    rebuilt = make_snapshot(current_session, [payload["snapshot"] for payload in organizations])

    args.session_file.parent.mkdir(parents=True, exist_ok=True)
    if args.session_file.exists():
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_path = args.session_file.with_name(f"{args.session_file.name}.pre-restore-{stamp}.bak")
        shutil.copy2(args.session_file, backup_path)
        print(f"Backed up current session to: {backup_path}")

    with args.session_file.open("w", encoding="utf-8") as handle:
        json.dump(rebuilt, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print(f"Wrote rebuilt session to: {args.session_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
