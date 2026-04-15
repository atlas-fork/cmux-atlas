#!/usr/bin/env python3
"""
Atlas-specific regression tests for Resources/bin/claude wrapper.

Covers features added in the atlas fork: resume flag detection,
CLAUDECODE unset, session ID generation, and wrapper passthrough behavior.
"""

from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE_WRAPPER = ROOT / "Resources" / "bin" / "claude"


def make_executable(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def read_lines(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines()]


def parse_env_lines(lines: list[str]) -> dict[str, str]:
    env: dict[str, str] = {}
    for line in lines:
        key, sep, value = line.partition("=")
        if sep:
            env[key] = value
    return env


def parse_settings_arg(argv: list[str]) -> dict:
    if "--settings" not in argv:
        return {}
    index = argv.index("--settings")
    if index + 1 >= len(argv):
        return {}
    return json.loads(argv[index + 1])


def run_wrapper(
    *,
    argv: list[str],
    socket_state: str = "live",
    env_overrides: dict[str, str] | None = None,
) -> tuple[int, list[str], str, dict[str, str], str]:
    """Run the claude wrapper in an isolated environment.

    Returns (exit_code, real_claude_args, claudecode_env_value, real_env, stderr).
    """
    with tempfile.TemporaryDirectory(prefix="cmux-claude-atlas-test-") as td:
        tmp = Path(td)
        wrapper_dir = tmp / "wrapper-bin"
        real_dir = tmp / "real-bin"
        wrapper_dir.mkdir(parents=True, exist_ok=True)
        real_dir.mkdir(parents=True, exist_ok=True)

        wrapper = wrapper_dir / "claude"
        shutil.copy2(SOURCE_WRAPPER, wrapper)
        wrapper.chmod(0o755)

        real_args_log = tmp / "real-args.log"
        real_claudecode_log = tmp / "real-claudecode.log"
        real_env_log = tmp / "real-env.log"
        cmux_log = tmp / "cmux.log"
        socket_path = str(tmp / "cmux.sock")

        make_executable(
            real_dir / "claude",
            f"""#!/usr/bin/env bash
set -euo pipefail
: > "{real_args_log}"
printf '%s\\n' "${{CLAUDECODE-__UNSET__}}" > "{real_claudecode_log}"
cat > "{real_env_log}" <<EOF
CMUX_CLAUDE_HOOK_CMUX_BIN=${{CMUX_CLAUDE_HOOK_CMUX_BIN-__UNSET__}}
NODE_OPTIONS=${{NODE_OPTIONS-__UNSET__}}
CMUX_ORIGINAL_NODE_OPTIONS=${{CMUX_ORIGINAL_NODE_OPTIONS-__UNSET__}}
CMUX_ORIGINAL_NODE_OPTIONS_PRESENT=${{CMUX_ORIGINAL_NODE_OPTIONS_PRESENT-__UNSET__}}
EOF
for arg in "$@"; do
  printf '%s\\n' "$arg" >> "{real_args_log}"
done
""",
        )

        make_executable(
            wrapper_dir / "cmux",
            f"""#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "{cmux_log}"
if [[ "${{1:-}}" == "--socket" ]]; then shift 2; fi
if [[ "${{1:-}}" == "ping" ]]; then
  [[ "${{FAKE_CMUX_PING_OK:-0}}" == "1" ]] && exit 0
  exit 1
fi
exit 0
""",
        )

        test_socket: socket.socket | None = None
        if socket_state in {"live", "stale"}:
            test_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            test_socket.bind(socket_path)

        env = os.environ.copy()
        env["PATH"] = f"{wrapper_dir}:{real_dir}:/usr/bin:/bin"
        env["CMUX_SURFACE_ID"] = "surface:test"
        env["CMUX_SOCKET_PATH"] = socket_path
        env["FAKE_CMUX_PING_OK"] = "1" if socket_state == "live" else "0"
        env["CLAUDECODE"] = "nested-session-sentinel"
        if env_overrides:
            env.update(env_overrides)

        try:
            proc = subprocess.run(
                ["claude", *argv],
                cwd=tmp,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
        finally:
            if test_socket is not None:
                test_socket.close()

        claudecode_lines = read_lines(real_claudecode_log)
        claudecode_value = claudecode_lines[0] if claudecode_lines else ""
        return (
            proc.returncode,
            read_lines(real_args_log),
            claudecode_value,
            parse_env_lines(read_lines(real_env_log)),
            proc.stderr.strip(),
        )


class TestClaudeWrapperAtlas(unittest.TestCase):
    def test_yolo_passes_through_unchanged(self):
        """--yolo is passed through unchanged by the wrapper."""
        rc, args, _, _, stderr = run_wrapper(argv=["--yolo"])
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        self.assertIn("--yolo", args)
        self.assertNotIn("--dangerously-skip-permissions", args)

    def test_resume_flag_skips_session_id(self):
        """--resume <id> suppresses --session-id injection."""
        rc, args, _, _, stderr = run_wrapper(argv=["--resume", "abc-123"])
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        self.assertIn("--resume", args)
        self.assertIn("abc-123", args)
        self.assertNotIn("--session-id", args)

    def test_continue_flag_skips_session_id(self):
        """--continue and -c suppress --session-id injection."""
        for flag in ["--continue", "-c"]:
            rc, args, _, _, stderr = run_wrapper(argv=[flag])
            self.assertEqual(rc, 0, f"Wrapper failed for {flag}: {stderr}")
            self.assertNotIn("--session-id", args, f"--session-id injected despite {flag}")

    def test_unsets_claudecode_env(self):
        """CLAUDECODE env var is unset to prevent nested session detection."""
        rc, args, claudecode_value, _, stderr = run_wrapper(argv=[])
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        self.assertEqual(claudecode_value, "__UNSET__", "CLAUDECODE was not unset")

    def test_session_id_generated_when_not_resuming(self):
        """A UUID --session-id is injected for fresh sessions."""
        rc, args, _, _, stderr = run_wrapper(argv=[])
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        self.assertIn("--session-id", args)
        sid_index = args.index("--session-id")
        self.assertTrue(sid_index + 1 < len(args), "--session-id has no value")
        session_id = args[sid_index + 1]
        # UUID format: 8-4-4-4-12 hex chars
        parts = session_id.split("-")
        self.assertEqual(len(parts), 5, f"Session ID not UUID format: {session_id}")

    def test_exports_resolved_hook_cmux_bin_and_node_options_guard(self):
        """Wrapper exports the bundled cmux path and OOM-safe NODE_OPTIONS."""
        rc, _, _, real_env, stderr = run_wrapper(
            argv=[],
            env_overrides={"NODE_OPTIONS": "--trace-warnings --max-old-space-size=1024"},
        )
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        resolved_cmux = real_env["CMUX_CLAUDE_HOOK_CMUX_BIN"]
        self.assertTrue(resolved_cmux.endswith("/cmux"), f"Expected a cmux executable path, got {resolved_cmux!r}")
        self.assertNotEqual(resolved_cmux, "cmux", "Expected resolved path, not bare cmux fallback")
        node_options = real_env["NODE_OPTIONS"]
        self.assertIn("--require=", node_options)
        self.assertIn("--max-old-space-size=4096", node_options)
        self.assertIn("--trace-warnings", node_options)
        self.assertNotIn("--max-old-space-size=1024", node_options)
        self.assertEqual(
            real_env["CMUX_ORIGINAL_NODE_OPTIONS"],
            "--trace-warnings --max-old-space-size=1024",
        )
        self.assertEqual(real_env["CMUX_ORIGINAL_NODE_OPTIONS_PRESENT"], "1")

    def test_custom_claude_path_overrides_path_lookup(self):
        """CMUX_CUSTOM_CLAUDE_PATH wins over PATH when it points to a real binary."""
        with tempfile.TemporaryDirectory(prefix="cmux-claude-atlas-test-") as td:
            tmp = Path(td)
            wrapper_dir = tmp / "wrapper-bin"
            real_dir = tmp / "real-bin"
            custom_dir = tmp / "custom-bin"
            wrapper_dir.mkdir(parents=True, exist_ok=True)
            real_dir.mkdir(parents=True, exist_ok=True)
            custom_dir.mkdir(parents=True, exist_ok=True)

            wrapper = wrapper_dir / "claude"
            shutil.copy2(SOURCE_WRAPPER, wrapper)
            wrapper.chmod(0o755)

            path_log = tmp / "path-real.log"
            custom_log = tmp / "custom-real.log"
            socket_path = str(tmp / "cmux.sock")

            make_executable(
                real_dir / "claude",
                f"""#!/usr/bin/env bash
set -euo pipefail
printf 'path\\n' > "{path_log}"
""",
            )
            custom_real = custom_dir / "claude-custom"
            make_executable(
                custom_real,
                f"""#!/usr/bin/env bash
set -euo pipefail
printf 'custom\\n' > "{custom_log}"
""",
            )
            make_executable(
                wrapper_dir / "cmux",
                """#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "--socket" ]] && shift 2
[[ "${1:-}" == "ping" ]] && exit 0
exit 0
""",
            )

            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.bind(socket_path)
            env = os.environ.copy()
            env["PATH"] = f"{wrapper_dir}:{real_dir}:/usr/bin:/bin"
            env["CMUX_SURFACE_ID"] = "surface:test"
            env["CMUX_SOCKET_PATH"] = socket_path
            env["CMUX_CUSTOM_CLAUDE_PATH"] = f"  {custom_real}  "
            try:
                proc = subprocess.run(
                    ["claude"],
                    cwd=tmp,
                    env=env,
                    capture_output=True,
                    text=True,
                    check=False,
                )
            finally:
                sock.close()

            self.assertEqual(proc.returncode, 0, f"Wrapper failed: {proc.stderr}")
            self.assertFalse(path_log.exists(), "PATH claude should not be used when custom path is set")
            self.assertEqual(custom_log.read_text(encoding="utf-8").strip(), "custom")


if __name__ == "__main__":
    unittest.main()
