#!/usr/bin/env python3
"""
Atlas regression tests for Resources/bin/codex wrapper.
"""

from __future__ import annotations

import os
import shutil
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE_WRAPPER = ROOT / "Resources" / "bin" / "codex"


def make_executable(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def read_lines(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines()]


def run_wrapper(
    *,
    socket_state: str = "live",
    argv: list[str] | None = None,
    env_overrides: dict[str, str] | None = None,
    set_surface_id: bool = True,
) -> tuple[int, list[str], list[str], str]:
    """Run the codex wrapper in an isolated environment.

    Returns (exit_code, real_codex_args, cmux_log_lines, stderr).
    """
    if argv is None:
        argv = []

    with tempfile.TemporaryDirectory(prefix="cmux-codex-wrapper-test-") as td:
        tmp = Path(td)
        wrapper_dir = tmp / "wrapper-bin"
        real_dir = tmp / "real-bin"
        wrapper_dir.mkdir(parents=True, exist_ok=True)
        real_dir.mkdir(parents=True, exist_ok=True)

        wrapper = wrapper_dir / "codex"
        shutil.copy2(SOURCE_WRAPPER, wrapper)
        wrapper.chmod(0o755)

        real_args_log = tmp / "real-args.log"
        real_env_log = tmp / "real-env.log"
        cmux_log = tmp / "cmux.log"
        socket_path = str(tmp / "cmux.sock")

        make_executable(
            real_dir / "codex",
            f"""#!/usr/bin/env bash
set -euo pipefail
: > "{real_args_log}"
printf 'CMUX_CODEX_PID=%s\\n' "${{CMUX_CODEX_PID:-__UNSET__}}" > "{real_env_log}"
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
if [[ "${{1:-}}" == "--socket" ]]; then
  shift 2
fi
if [[ "${{1:-}}" == "ping" ]]; then
  if [[ "${{FAKE_CMUX_PING_OK:-0}}" == "1" ]]; then
    exit 0
  fi
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
        env["CMUX_SOCKET_PATH"] = socket_path
        env["FAKE_CMUX_PING_OK"] = "1" if socket_state == "live" else "0"

        if set_surface_id:
            env["CMUX_SURFACE_ID"] = "surface:test"
        else:
            env.pop("CMUX_SURFACE_ID", None)

        if env_overrides:
            env.update(env_overrides)

        try:
            proc = subprocess.run(
                ["codex", *argv],
                cwd=tmp,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
        finally:
            if test_socket is not None:
                test_socket.close()

        return (
            proc.returncode,
            read_lines(real_args_log),
            read_lines(cmux_log),
            proc.stderr.strip(),
        )


class TestCodexWrapper(unittest.TestCase):
    def test_finds_real_codex_on_path(self):
        """Wrapper skips its own directory and finds the real codex binary."""
        rc, args, _, stderr = run_wrapper(socket_state="live", argv=["prompt"])
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")

    def test_injects_hooks_in_cmux(self):
        """Inside cmux with live socket, wrapper injects standard codex hook flags."""
        rc, args, _, stderr = run_wrapper(socket_state="live", argv=["prompt"])
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        self.assertIn("--enable", args)
        self.assertIn("codex_hooks", args)
        self.assertIn("--hook", args)
        hook_values = [args[i + 1] for i, a in enumerate(args) if a == "--hook" and i + 1 < len(args)]
        session_start_hooks = [h for h in hook_values if "session-start" in h]
        stop_hooks = [h for h in hook_values if "stop" in h]
        self.assertTrue(len(session_start_hooks) > 0, "Missing session-start hook")
        self.assertTrue(len(stop_hooks) > 0, "Missing stop hook")
        # Extended hooks should NOT be present without an explicit capability signal.
        prompt_submit_hooks = [h for h in hook_values if "prompt-submit" in h]
        session_end_hooks = [h for h in hook_values if "session-end" in h]
        self.assertEqual(len(prompt_submit_hooks), 0, "prompt-submit hook should not be injected without a dev-build signal")
        self.assertEqual(len(session_end_hooks), 0, "session-end hook should not be injected without a dev-build signal")

    def test_injects_extended_hooks_with_env_var(self):
        """CMUX_CODEX_EXTENDED_HOOKS=1 enables session-end and prompt-submit hooks."""
        rc, args, _, stderr = run_wrapper(
            socket_state="live",
            argv=["prompt"],
            env_overrides={"CMUX_CODEX_EXTENDED_HOOKS": "1"},
        )
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        hook_values = [args[i + 1] for i, a in enumerate(args) if a == "--hook" and i + 1 < len(args)]
        session_start_hooks = [h for h in hook_values if "session-start" in h]
        prompt_submit_hooks = [h for h in hook_values if "prompt-submit" in h]
        session_end_hooks = [h for h in hook_values if "session-end" in h]
        stop_hooks = [h for h in hook_values if "stop" in h]
        self.assertTrue(len(session_start_hooks) > 0, "Missing session-start hook")
        self.assertTrue(len(prompt_submit_hooks) > 0, "Missing prompt-submit hook")
        self.assertTrue(len(session_end_hooks) > 0, "Missing session-end hook")
        self.assertTrue(len(stop_hooks) > 0, "Missing stop hook")

    def test_injects_extended_hooks_for_ovm_codex_dev_builds(self):
        """ovm Codex dev-build env enables extended hooks without the cmux-specific override."""
        rc, args, _, stderr = run_wrapper(
            socket_state="live",
            argv=["prompt"],
            env_overrides={
                "OVM_PRODUCT": "codex",
                "OVM_DEV_BUILD": "1",
                "OVM_VERSION": "dev:resume-fix",
            },
        )
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        hook_values = [args[i + 1] for i, a in enumerate(args) if a == "--hook" and i + 1 < len(args)]
        self.assertTrue(any("prompt-submit" in hook for hook in hook_values), "Missing prompt-submit hook")
        self.assertTrue(any("session-end" in hook for hook in hook_values), "Missing session-end hook")

    def test_injects_extended_hooks_for_ovm_codex_dev_version(self):
        """ovm Codex dev-version env enables extended hooks even without OVM_DEV_BUILD."""
        rc, args, _, stderr = run_wrapper(
            socket_state="live",
            argv=["prompt"],
            env_overrides={
                "OVM_PRODUCT": "codex",
                "OVM_VERSION": "dev:resume-fix",
            },
        )
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        hook_values = [args[i + 1] for i, a in enumerate(args) if a == "--hook" and i + 1 < len(args)]
        self.assertTrue(any("prompt-submit" in hook for hook in hook_values), "Missing prompt-submit hook")
        self.assertTrue(any("session-end" in hook for hook in hook_values), "Missing session-end hook")

    def test_does_not_enable_extended_hooks_for_other_ovm_products(self):
        """ovm env alone should not enable Codex-only hooks for non-Codex products."""
        rc, args, _, stderr = run_wrapper(
            socket_state="live",
            argv=["prompt"],
            env_overrides={
                "OVM_PRODUCT": "claude",
                "OVM_DEV_BUILD": "1",
                "OVM_VERSION": "dev:feature-x",
            },
        )
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        hook_values = [args[i + 1] for i, a in enumerate(args) if a == "--hook" and i + 1 < len(args)]
        self.assertFalse(any("prompt-submit" in hook for hook in hook_values), "prompt-submit hook should stay disabled")
        self.assertFalse(any("session-end" in hook for hook in hook_values), "session-end hook should stay disabled")

    def test_passthrough_outside_cmux(self):
        """Without CMUX_SURFACE_ID, wrapper passes args unchanged to real codex."""
        rc, args, _, stderr = run_wrapper(
            socket_state="live",
            argv=["prompt"],
            set_surface_id=False,
        )
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        self.assertEqual(args, ["prompt"])
        self.assertNotIn("--enable", args)

    def test_passthrough_non_interactive_subcommands(self):
        """Subcommands like exec, review, login pass through without hooks."""
        for subcmd in ["exec", "review", "login", "logout", "help", "--help", "--version"]:
            rc, args, _, stderr = run_wrapper(socket_state="live", argv=[subcmd])
            self.assertEqual(rc, 0, f"Wrapper failed for {subcmd}: {stderr}")
            self.assertNotIn("--enable", args, f"Hooks injected for passthrough subcommand: {subcmd}")

    def test_hooks_disabled_flag(self):
        """CMUX_CODEX_HOOKS_DISABLED=1 bypasses hook injection."""
        rc, args, _, stderr = run_wrapper(
            socket_state="live",
            argv=["prompt"],
            env_overrides={"CMUX_CODEX_HOOKS_DISABLED": "1"},
        )
        self.assertEqual(rc, 0, f"Wrapper failed: {stderr}")
        self.assertNotIn("--enable", args)

    def test_exports_codex_pid(self):
        """CMUX_CODEX_PID is set when hooks are injected."""
        with tempfile.TemporaryDirectory(prefix="cmux-codex-wrapper-test-") as td:
            tmp = Path(td)
            wrapper_dir = tmp / "wrapper-bin"
            real_dir = tmp / "real-bin"
            wrapper_dir.mkdir(parents=True, exist_ok=True)
            real_dir.mkdir(parents=True, exist_ok=True)

            wrapper = wrapper_dir / "codex"
            shutil.copy2(SOURCE_WRAPPER, wrapper)
            wrapper.chmod(0o755)

            env_log = tmp / "env.log"
            make_executable(
                real_dir / "codex",
                f"""#!/usr/bin/env bash
printf '%s\\n' "${{CMUX_CODEX_PID:-__UNSET__}}" > "{env_log}"
""",
            )
            make_executable(
                wrapper_dir / "cmux",
                """#!/usr/bin/env bash
[[ "${1:-}" == "--socket" ]] && shift 2
[[ "${1:-}" == "ping" ]] && exit 0
exit 0
""",
            )

            socket_path = str(tmp / "cmux.sock")
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.bind(socket_path)

            env = os.environ.copy()
            env["PATH"] = f"{wrapper_dir}:{real_dir}:/usr/bin:/bin"
            env["CMUX_SURFACE_ID"] = "surface:test"
            env["CMUX_SOCKET_PATH"] = socket_path

            try:
                subprocess.run(
                    ["codex", "prompt"],
                    cwd=tmp, env=env, capture_output=True, text=True, check=False,
                )
            finally:
                sock.close()

            pid_value = env_log.read_text().strip()
            self.assertNotEqual(pid_value, "__UNSET__", "CMUX_CODEX_PID was not exported")
            self.assertTrue(pid_value.isdigit(), f"CMUX_CODEX_PID is not a number: {pid_value}")

    def test_ignores_removed_real_bin_override_env(self):
        """CMUX_CODEX_REAL_BIN no longer overrides PATH resolution."""
        with tempfile.TemporaryDirectory(prefix="cmux-codex-wrapper-test-") as td:
            tmp = Path(td)
            wrapper_dir = tmp / "wrapper-bin"
            real_dir = tmp / "real-bin"
            override_dir = tmp / "override-bin"
            wrapper_dir.mkdir(parents=True, exist_ok=True)
            real_dir.mkdir(parents=True, exist_ok=True)
            override_dir.mkdir(parents=True, exist_ok=True)

            wrapper = wrapper_dir / "codex"
            shutil.copy2(SOURCE_WRAPPER, wrapper)
            wrapper.chmod(0o755)

            path_log = tmp / "path-real.log"
            override_log = tmp / "override-real.log"
            make_executable(
                real_dir / "codex",
                f"""#!/usr/bin/env bash
set -euo pipefail
printf 'path\\n' > "{path_log}"
""",
            )
            override_real = override_dir / "codex-override"
            make_executable(
                override_real,
                f"""#!/usr/bin/env bash
set -euo pipefail
printf 'override\\n' > "{override_log}"
""",
            )
            make_executable(
                wrapper_dir / "cmux",
                """#!/usr/bin/env bash
[[ "${1:-}" == "--socket" ]] && shift 2
[[ "${1:-}" == "ping" ]] && exit 0
exit 0
""",
            )

            socket_path = str(tmp / "cmux.sock")
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.bind(socket_path)

            env = os.environ.copy()
            env["PATH"] = f"{wrapper_dir}:{real_dir}:/usr/bin:/bin"
            env["CMUX_SURFACE_ID"] = "surface:test"
            env["CMUX_SOCKET_PATH"] = socket_path
            env["CMUX_CODEX_REAL_BIN"] = str(override_real)
            try:
                proc = subprocess.run(
                    ["codex", "prompt"],
                    cwd=tmp,
                    env=env,
                    capture_output=True,
                    text=True,
                    check=False,
                )
            finally:
                sock.close()

            self.assertEqual(proc.returncode, 0, f"Wrapper failed: {proc.stderr}")
            self.assertEqual(path_log.read_text(encoding="utf-8").strip(), "path")
            self.assertFalse(
                override_log.exists(),
                "CMUX_CODEX_REAL_BIN should be ignored in favor of PATH resolution",
            )


if __name__ == "__main__":
    unittest.main()
