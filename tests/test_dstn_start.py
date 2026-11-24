"""The Windows start menu (Start-DSTN.bat -> scripts/dstn_start.ps1) is wired up as Windows PowerShell 5.1 needs it.

    python -I tests/test_dstn_start.py

Static checks only, so they run on any OS (no PowerShell, compiler or game files): the launcher stays ASCII for
cmd.exe, no "$name:" string trips the parser, the menu script keeps exactly one UTF-8 BOM (without it Windows PowerShell 5.1 reads the Russian text as
ANSI), every `-Step` name has a menu entry and a function, external probes go through the one helper that lowers
ErrorActionPreference (under Stop, Windows PowerShell 5.1 stops on a native program's first stderr line), and no
PowerShell 7-only operator slips in. Also: scripts/build_runtime.ps1 keeps one BOM and its -PipeOutput launch.
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAT = os.path.join(ROOT, "Start-DSTN.bat")
MENU = os.path.join(ROOT, "scripts", "dstn_start.ps1")
BUILD = os.path.join(ROOT, "scripts", "build_runtime.ps1")
BOM = b"\xef\xbb\xbf"


def read_bytes(path):
    with open(path, "rb") as f:
        return f.read()


def code_lines(text):
    """The script's lines without full-line comments and without the contents of quoted strings."""
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue
        line = re.sub(r'"(?:[^"`]|`.)*"', '""', line)
        line = re.sub(r"'[^']*'", "''", line)
        out.append(line)
    return out


class StartMenuTest(unittest.TestCase):
    def test_launcher_is_ascii_and_starts_the_menu(self):
        data = read_bytes(BAT)
        self.assertTrue(all(b < 0x80 for b in data), "Start-DSTN.bat must stay ASCII")
        text = data.decode("ascii")
        self.assertIn(r'-ExecutionPolicy Bypass -File "%~dp0scripts\dstn_start.ps1" %*', text)
        self.assertIn("-NoProfile", text)
        self.assertIn(r"WindowsPowerShell\v1.0\powershell.exe", text)

    def test_menu_script_has_exactly_one_bom(self):
        data = read_bytes(MENU)
        self.assertTrue(data.startswith(BOM), "dstn_start.ps1 needs a UTF-8 BOM for Windows PowerShell 5.1")
        self.assertFalse(data.startswith(BOM + BOM), "dstn_start.ps1 has a doubled BOM")
        data[len(BOM):].decode("utf-8")

    def test_every_step_has_a_menu_entry_and_a_function(self):
        text = read_bytes(MENU)[len(BOM):].decode("utf-8")
        valid = re.search(r'\[ValidateSet\(([^)]*)\)\]\s*\[string\]\$Step', text)
        self.assertIsNotNone(valid)
        steps = [s for s in re.findall(r'"([^"]*)"', valid.group(1)) if s]
        entries = re.findall(r'^\s*"(\d)" = @\{ Key = "([^"]+)";\s*Title = "[^"]+";\s*Run = \{ (Step-[\w-]+) \} \}',
                             text, re.M)
        self.assertEqual([key for _, key, _ in entries], steps, "ValidateSet and the menu entries differ")
        self.assertEqual([number for number, _, _ in entries], [str(i) for i in range(1, len(entries) + 1)])
        functions = set(re.findall(r"^function (Step-[\w-]+)", text, re.M))
        self.assertEqual({fn for _, _, fn in entries} - functions, set(), "a menu entry names no function")

    def test_native_stderr_is_only_dropped_inside_the_quiet_helper(self):
        text = read_bytes(MENU)[len(BOM):].decode("utf-8")
        helper = re.search(r"^function Invoke-Quiet.*?^}", text, re.M | re.S).group(0)
        self.assertIn('$ErrorActionPreference = "Continue"', helper)
        outside = text.replace(helper, "")
        self.assertEqual(re.findall(r".*2>\$null.*", outside), [])

    def test_no_powershell_7_only_operators(self):
        text = read_bytes(MENU)[len(BOM):].decode("utf-8")
        for number, line in enumerate(code_lines(text), 1):
            with self.subTest(line=number):
                self.assertNotRegex(line, r"\?\?|\?\.|\s&&\s|\s\|\|\s|\?\s*[^:]+\s:\s")

    def test_no_variable_is_followed_by_a_colon_inside_a_string(self):
        # "$code: ..." parses as a scope-qualified name ($scope:name) and is a syntax error; "$($code): ..." is not.
        text = read_bytes(MENU)[len(BOM):].decode("utf-8")
        for number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for string in re.findall(r'"(?:[^"`]|`.)*"', line):
                with self.subTest(line=number):
                    self.assertNotRegex(string, r"\$(?!env:|script:|global:|using:)[A-Za-z_]\w*:")

    def test_python_runs_isolated_in_utf8_mode(self):
        text = read_bytes(MENU)[len(BOM):].decode("utf-8")
        self.assertIn('@("-I", "-X", "utf8")', text)

    def test_build_script_has_one_bom_and_a_pipe_mode(self):
        data = read_bytes(BUILD)
        self.assertTrue(data.startswith(BOM))
        self.assertFalse(data.startswith(BOM + BOM), "build_runtime.ps1 has a doubled BOM")
        text = data[len(BOM):].decode("utf-8")
        self.assertIn("[switch]$PipeOutput", text)
        self.assertIn('& cmd.exe --% /s /c ""%DSTN_BUILD_CMD%"" 2>&1', text)
        self.assertEqual(len(re.findall(r"^\$p = Start-Process cmd\.exe", text, re.M)), 1)
        menu = read_bytes(MENU)[len(BOM):].decode("utf-8")
        self.assertIn('"build_runtime.ps1"), "-PipeOutput")', menu)


if __name__ == "__main__":
    unittest.main()
