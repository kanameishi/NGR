import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


NGR_TEST_BIN = os.environ["NGR_TEST_BIN"]
NGR_TEST_ROOT = os.environ["NGR_TEST_ROOT"]


def snapshot(root):
    return {str(x.relative_to(root)): hashlib.sha256(x.read_bytes()).hexdigest()
            for x in root.rglob("*") if x.is_file()}


class ResourcesTest(unittest.TestCase):
    def setUp(self):
        self.Directory = tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT)
        self.addCleanup(self.Directory.cleanup)
        self.Root = Path(self.Directory.name)
        self.Project = self.Root / "project with spaces"
        self.Project.mkdir()

    def makeSource(self, name, files, seeds=()):
        Root = self.Root / name
        Root.mkdir(exist_ok=True)
        Resources = []
        for Name, Content in files.items():
            FILE = Root / Name
            FILE.parent.mkdir(parents=True, exist_ok=True)
            FILE.write_text(Content, encoding="utf-8")
            Resources.append({"from": Name, "to": Name, "ownership": "seed" if Name in seeds else "managed"})
        Manifest = Root / "manifest.json"
        Manifest.write_text(json.dumps({"schemaVersion": 1, "id": name, "resources": Resources}), encoding="utf-8")
        return Manifest

    def runCli(self, *args, expected=0):
        DATA = subprocess.run([NGR_TEST_BIN, *map(str, args)], cwd=self.Project, capture_output=True, text=True)
        self.assertEqual(DATA.returncode, expected, DATA.stdout + DATA.stderr)
        return DATA

    def testFirstPullUpdateAndSeeds(self):
        Source = self.makeSource("a", {"scripts/plot.R": "v1", "params.yml": "seed", "_master/book.qmd": "master"}, seeds=("params.yml", "_master/book.qmd"))
        self.runCli("pull", "--from", Source)
        (self.Project / "params.yml").write_text("project")
        (self.Project / "_master/book.qmd").write_text("edited")
        (self.Project / "oq").mkdir()
        (self.Project / "oq/result.txt").write_text("scientific")
        (Source.parent / "scripts/plot.R").write_text("v2")
        Before = snapshot(self.Project)
        self.runCli("pull", expected=1)
        self.assertEqual(snapshot(self.Project), Before)
        self.runCli("pull", "--force")
        self.assertEqual((self.Project / "scripts/plot.R").read_text(), "v2")
        self.assertEqual((self.Project / "params.yml").read_text(), "project")
        self.assertEqual((self.Project / "_master/book.qmd").read_text(), "edited")
        self.assertEqual((self.Project / "oq/result.txt").read_text(), "scientific")
        self.runCli("status", "--check")

    def testCanonicalManifestAndBaseSource(self):
        self.runCli("pull", "--from", "ngr", "yml")
        Manifest = self.Project / "manifest.json"
        self.assertTrue(Manifest.is_file())
        self.assertFalse((self.Project / "qrt.manifest.json").exists())
        DATA = json.loads(Manifest.read_text())
        self.assertEqual(Path(DATA["scaffolds"]["ngr"]["manifest"]).name, "manifest.json")
        self.runCli("pull")
        self.runCli("status", "--check")

    def testBaseLeavesBibliographyToBook(self):
        Source = self.makeSource("book", {"bib/references.bib": "@book{report}"})
        self.runCli("pull", "--from", "ngr", "--from", Source)
        self.assertEqual((self.Project / "bib/references.bib").read_text(), "@book{report}")
        self.assertTrue((self.Project / "bib/apa.csl").is_file())
        Manifest = json.loads((self.Project / "manifest.json").read_text())
        self.assertNotIn("bib/references.bib", Manifest["scaffolds"]["ngr"]["claims"])
        self.runCli("status", "--check")

    def testLegacyManifestCoexistsUnchanged(self):
        Source = self.makeSource("a", {"_fig/a.qmd": "a"})
        Content = json.dumps(dict(schemaVersion=2, artifacts=[], scaffolds={}))
        (self.Project / "qrt.manifest.json").write_text(Content)
        for Both in (False, True):
            if Both:
                (self.Project / "manifest.json").write_text(Content)
            for Args in (("pull", "--from", Source, "--force"), ("status",), ("check",)):
                with self.subTest(both=Both, args=Args):
                    self.runCli(*Args)
            self.assertEqual((self.Project / "qrt.manifest.json").read_text(), Content)

    def testSourceCannotSupplyProjectManifest(self):
        Source = self.makeSource("a", {"data.json": "{}"})
        DATA = json.loads(Source.read_text())
        DATA["resources"][0]["to"] = "manifest.json"
        Source.write_text(json.dumps(DATA))
        self.runCli("pull", "--from", Source, "--force", expected=1)
        self.assertEqual(snapshot(self.Project), {})

    def testSourcesConflictBeforeAnyCopy(self):
        SourceA = self.makeSource("a", {"scripts/plot.R": "a", "_fig/a.qmd": "a"})
        SourceB = self.makeSource("b", {"scripts/plot.R": "b", "_fig/b.qmd": "b"})
        self.runCli("pull", "--from", SourceA, "--from", SourceB, "--force", expected=1)
        self.assertEqual(snapshot(self.Project), {})

    def testUnselectedSourceClaimAndPartialProvenance(self):
        SourceA = self.makeSource("a", {"scripts/shared.R": "same", "_fig/a.qmd": "a"})
        SourceB = self.makeSource("b", {"scripts/shared.R": "same", "_fig/b.qmd": "b"})
        self.runCli("pull", "--from", SourceA, "--from", SourceB)
        Before = snapshot(self.Project)
        (SourceA.parent / "scripts/shared.R").write_text("changed")
        self.runCli("pull", "--source", "a", "scripts", "--force", expected=1)
        self.assertEqual(snapshot(self.Project), Before)
        (SourceA.parent / "_fig/a.qmd").write_text("a2")
        self.runCli("pull", "--source", "a", "_fig", "--force")
        DATA = json.loads((self.Project / "manifest.json").read_text())
        self.assertEqual(DATA["scaffolds"]["a"]["files"]["scripts/shared.R"]["md5"], hashlib.md5(b"same").hexdigest())
        self.assertEqual(DATA["scaffolds"]["a"]["files"]["_fig/a.qmd"]["md5"], hashlib.md5(b"a2").hexdigest())

    def testDryRunAndLocalDrift(self):
        Source = self.makeSource("a", {"_fig/a.qmd": "a"})
        self.runCli("pull", "--from", Source, "--dry-run")
        self.assertEqual(snapshot(self.Project), {})
        self.runCli("pull", "--from", Source)
        (self.Project / "_fig/a.qmd").write_text("local")
        self.assertIn("locally-modified", self.runCli("status", "--check", expected=1).stdout)
        self.runCli("pull", "--source", "unknown", expected=1)

    def testEscapesAndSymlinks(self):
        Source = self.makeSource("a", {"_fig/a.qmd": "a"})
        (self.Project / "_fig").symlink_to(Source.parent / "_fig", target_is_directory=True)
        self.runCli("pull", "--from", Source, expected=1)
        self.assertEqual((Source.parent / "_fig/a.qmd").read_text(), "a")
        DATA = json.loads(Source.read_text())
        DATA["resources"][0]["to"] = "../escape"
        Source.write_text(json.dumps(DATA))
        self.runCli("pull", "--from", Source, expected=1)
        self.assertFalse((self.Root / "escape").exists())
        DATA["resources"][0]["to"] = "OQ/result.txt"
        Source.write_text(json.dumps(DATA))
        self.runCli("pull", "--from", Source, "--force", expected=1)
        self.assertFalse((self.Project / "OQ").exists())

    def testSourceLinksAndDanglingDestination(self):
        Source = self.makeSource("a", {"_fig/a.qmd": "a"})
        File = Source.parent / "_fig/a.qmd"
        Target = Source.parent / "_fig/actual.qmd"
        File.rename(Target)
        File.symlink_to(Target)
        self.runCli("pull", "--from", Source, expected=1)
        self.assertEqual(list(self.Project.iterdir()), [])
        File.unlink()
        Target.rename(File)
        Missing = self.Root / "missing-target"
        (self.Project / "_fig").symlink_to(Missing, target_is_directory=True)
        self.runCli("pull", "--from", Source, "--force", expected=1)
        self.assertFalse(Missing.exists())
        self.assertFalse((self.Project / "manifest.json").exists())

    def testSeedClaimsAndCaseCollisions(self):
        SourceA = self.makeSource("a", {"params.yml": "a"}, seeds=("params.yml",))
        SourceB = self.makeSource("b", {"params.yml": "b"}, seeds=("params.yml",))
        self.runCli("pull", "--from", SourceA, "--from", SourceB, "--force", expected=1)
        SourceB = self.makeSource("b", {"PARAMS.yml": "a"}, seeds=("PARAMS.yml",))
        self.runCli("pull", "--from", SourceA, "--from", SourceB, "--force", expected=1)
        self.assertEqual(snapshot(self.Project), {})

    def testProjectManifestAndRemovedResourcePreserved(self):
        Source = self.makeSource("a", {"a.txt": "a", "b.txt": "b"})
        self.runCli("pull", "--from", Source)
        Manifest = self.Project / "manifest.json"
        DATA = json.loads(Manifest.read_text())
        DATA["artifacts"] = [{"alias": "custom", "path": "html/custom"}]
        DATA["owner"] = "project"
        Manifest.write_text(json.dumps(DATA))
        DATA = json.loads(Source.read_text())
        DATA["resources"] = DATA["resources"][:1]
        Source.write_text(json.dumps(DATA))
        self.runCli("pull", "--force")
        self.assertEqual((self.Project / "b.txt").read_text(), "b")
        self.assertIn("retired", self.runCli("status").stdout)
        DATA = json.loads(Manifest.read_text())
        self.assertEqual(DATA["owner"], "project")
        self.assertEqual(DATA["artifacts"][0]["alias"], "custom")

if __name__ == "__main__":
    unittest.main()
