#!/usr/bin/env python3
"""Read-only verifier regression tests; no actual apps or USB devices are needed."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class VerifyTests(unittest.TestCase):
    def run_check(self, usb="        iPad:\n", log="mode extend\n", app=True, usb_status=0):
        with tempfile.TemporaryDirectory(prefix="opendisplay-test-") as directory:
            root = Path(directory)
            profiler = root / "system_profiler"
            profiler.write_text('#!/bin/sh\nprintf "%s" "$TEST_USB"\nexit "$TEST_USB_STATUS"\n')
            profiler.chmod(0o700)
            if app:
                (root / "OpenDisplay.app").mkdir()
            if log is not None:
                (root / "opendisplay.log").write_text(log)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}",
                       OPENDISPLAY_APP_PATH=str(root / "OpenDisplay.app"),
                       OPENDISPLAY_LOG_PATH=str(root / "opendisplay.log"),
                       TEST_USB=usb, TEST_USB_STATUS=str(usb_status))
            return subprocess.run(["zsh", str(Path(__file__).with_name("setup-opendisplay.sh")), "--verify"],
                                  env=env, capture_output=True, text=True)

    def test_ipad_and_iphone(self):
        for name in ("iPad", "iPad Pro", "iPhone", "iPhone 16 Pro"):
            result = self.run_check(usb=f"        {name}:\n")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_other_apple_device_is_not_receiver(self):
        result = self.run_check(usb="        Apple Keyboard:\n          Manufacturer: Apple Inc.\n")
        self.assertEqual(result.returncode, 1)
        self.assertIn("USB: not detected", result.stdout)

    def test_missing_sender(self):
        self.assertEqual(self.run_check(app=False).returncode, 1)

    def test_usb_inspection_failure(self):
        result = self.run_check(usb_status=1)
        self.assertEqual(result.returncode, 1)
        self.assertIn("inspection failed", result.stdout)

    def test_missing_vs_unmatched_log(self):
        missing = self.run_check(log=None)
        unmatched = self.run_check(log="unrelated event\n")
        self.assertEqual(missing.returncode, 1)
        self.assertEqual(unmatched.returncode, 1)
        self.assertIn("log: not found", missing.stdout)
        self.assertIn("present, but no relevant events", unmatched.stdout)
        self.assertNotIn("log: not found", unmatched.stdout)

    def test_latest_event_controls_result(self):
        for event in ("Connection lost", "Mirroring to iPad", "mode mirror", "Failed to find any displays"):
            self.assertEqual(self.run_check(log=f"mode extend\n{event}\n").returncode, 1)
        self.assertEqual(self.run_check(log="Connection lost\nmode extend\n").returncode, 0)

    def test_virtual_display_alone_is_inconclusive(self):
        self.assertEqual(self.run_check(log="virtual display created\n").returncode, 1)

    def test_old_extend_outside_tail_is_inconclusive(self):
        self.assertEqual(self.run_check(log="mode extend\n" + "unrelated\n" * 80).returncode, 1)


if __name__ == "__main__":
    unittest.main()
