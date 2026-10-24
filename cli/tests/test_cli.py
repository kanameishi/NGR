import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import shutil


NGR_TEST_BIN = os.environ["NGR_TEST_BIN"]
NGR_TEST_ROOT = os.environ["NGR_TEST_ROOT"]


class CliTest(unittest.TestCase):
    def setUp(self):
        self.Directory = tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT)
        self.addCleanup(self.Directory.cleanup)
        self.Root = Path(self.Directory.name)

    def runCli(self, *args, env=None):
        return subprocess.run([NGR_TEST_BIN, *args], cwd=self.Root,
                              env=env, capture_output=True, text=True)

    def testResourceHelpNamesPublicCommandAndApplicableOptions(self):
        for Command, Present, Absent in (
            ("pull", ("--from", "--source", "--force", "--dry-run", "TARGETS"), ("--check",)),
            ("status", ("--from", "--source", "--check", "TARGETS"), ("--force", "--dry-run")),
            ("doctor", ("--source",), ("--from", "--force", "--dry-run", "--check", "TARGETS")),
        ):
            with self.subTest(command=Command):
                DATA = self.runCli(Command, "--help")
                self.assertEqual(DATA.returncode, 0, DATA.stderr)
                self.assertIn(f"usage: ngr {Command} ", DATA.stdout)
                for x in Present:
                    self.assertIn(x, DATA.stdout)
                for x in Absent:
                    self.assertNotIn(x, DATA.stdout)
                self.assertNotIn("resources.py", DATA.stdout)
        self.assertEqual(list(self.Root.iterdir()), [])

    def testResourceOptionsRejectInvalidCommands(self):
        for Args in (("pull", "--check"), ("status", "--force"),
                     ("status", "--dry-run"), ("doctor", "--from", "ngr"),
                     ("doctor", "scripts")):
            with self.subTest(args=Args):
                DATA = self.runCli(*Args)
                self.assertEqual(DATA.returncode, 2, DATA.stdout + DATA.stderr)
        self.assertEqual(list(self.Root.iterdir()), [])

    def testManifestRenderRejectsUnusedArgumentsBeforeEffects(self):
        (self.Root / "html").mkdir()
        (self.Root / "html/index.html").write_text("static sentinel")
        Manifest = self.Root / "manifest.json"
        Manifest.write_text(json.dumps(dict(schemaVersion=2, artifacts=[
            dict(alias="page", kind="static", path="html", required=True)])))
        for Args in (("--unexpected-option",), ("--dry-run", "--unexpected-option")):
            with self.subTest(args=Args):
                DATA = self.runCli("render", "--manifest", str(Manifest), *Args)
                self.assertNotEqual(DATA.returncode, 0, DATA.stdout + DATA.stderr)
                self.assertIn("--unexpected-option", DATA.stderr)
                self.assertNotIn("[render manifest]", DATA.stdout)
        self.assertEqual((self.Root / "html/index.html").read_text(), "static sentinel")

    def testDeployActionHelpDoesNotNeedProviderOrProject(self):
        # Help needs the declared R runtime, but no provider command.
        Env = dict(os.environ, PATH=str(Path(shutil.which("Rscript")).resolve().parent) + os.pathsep + os.defpath)
        for Action in ("init", "domain", "unbind"):
            for Flag in ("--help", "-h"):
                with self.subTest(action=Action, flag=Flag):
                    DATA = self.runCli("deploy", Action, Flag, env=Env)
                    self.assertEqual(DATA.returncode, 0, DATA.stdout + DATA.stderr)
                    self.assertIn(f"ngr deploy {Action} ", DATA.stdout)
                    self.assertEqual(DATA.stderr, "")
        self.assertEqual(list(self.Root.iterdir()), [])

    def testDiagnosticsFollowTheFamilyRenderer(self):
        for Args, Status, Line in ((("unknown",), 2, "ngr: Unknown command: unknown; use ngr --help"),
                                   (("render", "--manifest"), 2, "ngr: --manifest requires a value."),
                                   (("pull", "--source", "missing"), 1, "ngr: Unknown registered source: missing")):
            with self.subTest(args=Args):
                DATA = self.runCli(*Args)
                self.assertEqual(DATA.returncode, Status, DATA.stdout + DATA.stderr)
                self.assertEqual(DATA.stdout, "")
                self.assertEqual(DATA.stderr, Line + "\n")
        DATA = self.runCli("deploy")
        self.assertEqual((DATA.returncode, DATA.stderr), (0, ""))
        self.assertIn("ngr deploy unbind <alias>", DATA.stdout)
        Version = self.runCli("--version").stdout.splitlines()[0]
        for Flags, Note in (((), Version), (("--quiet",), None), (("--verbose",), Version + " [operation=doctor]"),
                            (("--verbose", "--quiet"), None)):
            with self.subTest(flags=Flags):
                DATA = self.runCli(*Flags, "doctor")
                self.assertEqual(DATA.returncode, 0, DATA.stdout + DATA.stderr)
                self.assertEqual(DATA.stdout, "[doctor] declared checks passed\n")
                self.assertEqual(DATA.stderr, "" if Note is None else Note + "\n")
        self.assertEqual(list(self.Root.iterdir()), [])

    def testHelpNeedsNoLibraryAndAnOlderLibraryIsNamed(self):
        with tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT) as DIR:
            Library = Path(DIR) / "library"
            Library.mkdir()
            Profile = Path(DIR) / "empty"
            Profile.write_text("")
            Environment = dict(os.environ, R_LIBS=str(Library), R_LIBS_USER=str(Library), R_LIBS_SITE=str(Library),
                               R_PROFILE_USER=str(Profile), R_ENVIRON_USER=str(Profile))
            for Args in (("--help",), ("pull", "--help"), ("render", "--help"), ("deploy", "--help"), ("--version",)):
                with self.subTest(args=Args):
                    DATA = self.runCli(*Args, env=Environment)
                    self.assertEqual(DATA.returncode, 0, DATA.stdout + DATA.stderr)
            # A system library may still hold an older NGR; either way the command names the cause.
            self.assertRegex(self.runCli("--version", env=Environment).stdout, r"NGR is not installed|NGR \d")
            DATA = self.runCli("status", env=Environment)
            self.assertEqual(DATA.returncode, 1, DATA.stdout + DATA.stderr)
            # The renderer names the package version it found after an error outside the family.
            self.assertRegex(DATA.stderr, r"is not installed|Package found: NGR \d")
            Package = Path(DIR) / "NGR"
            Package.mkdir()
            (Package / "DESCRIPTION").write_text("Package: NGR\nVersion: 0.0.1\nTitle: Older Library\n"
                                                 "Description: Stands for an installed older library.\nLicense: MIT\n")
            (Package / "NAMESPACE").write_text("")
            subprocess.run(["Rscript", "-e", "install.packages(commandArgs(TRUE)[1], lib = commandArgs(TRUE)[2], repos = NULL, type = 'source')",
                            Package.as_posix(), Library.as_posix()], check=True, capture_output=True, env=Environment)
            DATA = self.runCli("status", env=Environment)
            self.assertEqual(DATA.returncode, 1, DATA.stdout + DATA.stderr)
            self.assertIn("Package found: NGR 0.0.1", DATA.stderr)
            # The failure names the version found, never the path of the library.
            self.assertNotIn(str(Library), DATA.stderr)
            self.assertEqual(self.runCli("--help", env=Environment).returncode, 0)
        self.assertEqual(list(self.Root.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
