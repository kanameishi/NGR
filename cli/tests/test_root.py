import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


NGR_TEST_BIN = os.environ["NGR_TEST_BIN"]
NGR_TEST_ROOT = os.environ["NGR_TEST_ROOT"]


def snapshot(root):
    return {str(x.relative_to(root)): hashlib.sha256(x.read_bytes()).hexdigest()
            for x in root.rglob("*") if x.is_file()}


class RootTest(unittest.TestCase):
    def setUp(self):
        self.Directory = tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT)
        self.addCleanup(self.Directory.cleanup)
        self.Root = Path(self.Directory.name)
        self.Project = self.Root / "project with spaces"
        self.Source = self.Root / "source with spaces"
        self.Project.mkdir()
        self.Source.mkdir()
        (self.Source / "note.txt").write_text("source data")
        DATA = dict(schemaVersion=1, id="fixture", resources=[
            {"from": "note.txt", "to": "note.txt", "ownership": "managed"}],
            checks=[[sys.executable, "-c",
                     "from pathlib import Path; assert Path('note.txt').read_text() == 'source data'"]])
        (self.Source / "manifest.json").write_text(json.dumps(DATA))

    def runCli(self, *args, cwd=None, expected=0):
        DATA = subprocess.run([NGR_TEST_BIN, *map(str, args)],
                              cwd=self.Root if cwd is None else cwd,
                              capture_output=True, text=True)
        self.assertEqual(DATA.returncode, expected, DATA.stdout + DATA.stderr)
        return DATA

    def testRootTransportsResourcesChecksAndPlans(self):
        Source = "../source with spaces/manifest.json"
        Before = snapshot(self.Root)
        self.runCli("pull", "--root", self.Project.name, "--from", Source, "--dry-run")
        self.assertEqual(snapshot(self.Root), Before)
        self.runCli("--root", self.Project.name, "pull", "--from", Source)
        self.assertEqual((self.Project / "note.txt").read_text(), "source data")
        self.assertFalse((self.Root / "manifest.json").exists())
        self.runCli("status", f"--root={self.Project}", "--check")
        self.runCli("check", "--root", self.Project)
        (self.Project / "html/page").mkdir(parents=True)
        (self.Project / "html/page/index.html").write_text("static data")
        Manifest = self.Project / "manifest.json"
        DATA = json.loads(Manifest.read_text())
        DATA["schemaVersion"] = 2
        DATA["artifacts"] = [dict(alias="page", kind="static", path="html/page", required=True,
                                  siteSlug="fixture", domain="fixture.example.invalid")]
        Manifest.write_text(json.dumps(DATA))
        Before = snapshot(self.Root)
        self.runCli("render", "--root", self.Project, "--manifest", "manifest.json", "--dry-run")
        self.runCli("deploy", "init", "--root", self.Project, "--manifest", "manifest.json", "--dry-run")
        self.assertEqual(snapshot(self.Root), Before)

    def testCwdAndInvalidRoots(self):
        self.runCli("pull", "--from", self.Source / "manifest.json", cwd=self.Project)
        self.runCli("status", "--check", cwd=self.Project)
        Before = snapshot(self.Root)
        for Args in (("pull", "--root", "missing"),
                     ("pull", "--root", self.Project / "note.txt"),
                     ("pull", "--root"),
                     ("pull", "--root", self.Project, "--root", self.Source)):
            with self.subTest(args=Args):
                self.runCli(*Args, expected=2)
                self.assertEqual(snapshot(self.Root), Before)


if __name__ == "__main__":
    unittest.main()
