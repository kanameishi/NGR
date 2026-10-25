import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


NGR_TEST_BIN = os.environ["NGR_TEST_BIN"]
NGR_TEST_ROOT = os.environ["NGR_TEST_ROOT"]
NGR_RESOURCE_REFERENCE = os.environ.get("NGR_RESOURCE_REFERENCE")


def resourceSnapshot(root):
    Result = {}
    for FILE in root.rglob("*"):
        if not FILE.is_file():
            continue
        Name = FILE.relative_to(root).as_posix()
        if Name == "qrt.manifest.json":
            Name = "manifest.json"
        assert Name not in Result, "Both project manifest names are present"
        Result[Name] = (json.loads(FILE.read_text()) if Name == "manifest.json"
                        else hashlib.sha256(FILE.read_bytes()).hexdigest())
    return Result


class ResourceApiTest(unittest.TestCase):
    @unittest.skipUnless(NGR_RESOURCE_REFERENCE, "requires the preserved resource CLI")
    def testMigratedAssociationPreservesReceipts(self):
        with tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT) as DIR:
            Root = Path(DIR)
            Source = Root / "source"
            Project = Root / "project"
            Source.mkdir()
            Project.mkdir()
            (Source / "chapter.qmd").write_text("preserved chapter")
            Manifest = Source / "ngr.source.json"
            Manifest.write_text(json.dumps(dict(schemaVersion=1, id="book", resources=[
                {"from": "chapter.qmd", "to": "_chapters/chapter.qmd", "ownership": "managed"}])))
            DATA = subprocess.run([NGR_RESOURCE_REFERENCE, "pull", "--from", str(Manifest)],
                                  cwd=Project, capture_output=True, text=True)
            self.assertEqual(DATA.returncode, 0, DATA.stderr)
            Manifest.rename(Source / "manifest.json")
            (Project / "qrt.manifest.json").rename(Project / "manifest.json")
            Manifest = Project / "manifest.json"
            Content = json.loads(Manifest.read_text())
            Content["scaffolds"]["book"]["manifest"] = str((Source / "manifest.json").resolve())
            Manifest.write_text(json.dumps(Content))
            Before = resourceSnapshot(Project)
            for Args in (("status", "--check"), ("pull",)):
                DATA = subprocess.run([NGR_TEST_BIN, *Args], cwd=Project, capture_output=True, text=True)
                self.assertEqual(DATA.returncode, 0, DATA.stdout + DATA.stderr)
                self.assertEqual(resourceSnapshot(Project), Before)

    def testInstalledLibraryAndDriverBoundary(self):
        Runtime = Path(NGR_TEST_BIN).resolve().parents[1]
        self.assertFalse((Runtime / "lib/resources.py").exists())
        with tempfile.TemporaryDirectory(prefix="ngr-api-independent-") as DIR:
            Environment = dict(os.environ)
            Environment.pop("PATH_NGR", None)
            Tests = Path(__file__).resolve().parents[2] / "lib/tests/testthat/test-resources.R"
            DATA = subprocess.run(["Rscript", "-e",
                'stopifnot(all(c("pullResources", "compareResources", "checkResources") %in% '
                'getNamespaceExports("NGR"))); '
                'testthat::test_file(commandArgs(TRUE)[[1L]], package="NGR", stop_on_failure=TRUE)',
                str(Tests)], cwd=DIR, env=Environment, capture_output=True, text=True)
            self.assertEqual(DATA.returncode, 0, DATA.stdout + DATA.stderr)

    @unittest.skipUnless(NGR_RESOURCE_REFERENCE, "requires the preserved resource CLI")
    def testDeclaredChecksParity(self):
        with tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT) as DIR:
            Root = Path(DIR)
            Script = Root / "check resources.R"
            Script.write_text('stopifnot(identical(commandArgs(TRUE), "a b;$(bad)"))')
            Projects = [Root / "reference", Root / "candidate"]
            for Project, Name in zip(Projects, ("qrt.manifest.json", "manifest.json")):
                Project.mkdir()
                (Project / Name).write_text(json.dumps(dict(schemaVersion=2,
                    artifacts=[], scaffolds=dict(source=dict(checks=[["Rscript", str(Script), "a b;$(bad)"]])))))
            Before = resourceSnapshot(Projects[0])
            for Failure in (False, True):
                if Failure:
                    Script.write_text('stop("declared failure")')
                # The reference runs the declared checks under doctor; this command runs them under check.
                Results = [subprocess.run([Binary, Verb, "--source", "source"],
                    cwd=Project, capture_output=True, text=True)
                    for Binary, Verb, Project in zip((NGR_RESOURCE_REFERENCE, NGR_TEST_BIN), ("doctor", "check"), Projects)]
                for Result in Results:
                    self.assertEqual(Result.returncode, int(Failure), Result.stdout + Result.stderr)
                # Each declared check is now a progress line on stderr; stdout keeps the closing line.
                self.assertEqual([x.replace("[doctor]", "[check]", 1) for x in Results[0].stdout.splitlines()
                                  if not x.startswith("[doctor] source: ")],
                                 Results[1].stdout.splitlines())
                self.assertIn("source: ", Results[1].stderr)
                for Project in Projects:
                    self.assertEqual(resourceSnapshot(Project), Before)

    @unittest.skipUnless(NGR_RESOURCE_REFERENCE, "requires the preserved resource CLI")
    def testPreservedResourceCliParity(self):
        with tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT) as DIR:
            Root = Path(DIR)
            Source = Root / "source"
            Source.mkdir()
            (Source / "a.txt").write_text("one")
            (Source / "b.txt").write_text("two")
            (Source / "seed.yml").write_text("seed")
            Manifest = Source / "manifest.json"
            Content = dict(schemaVersion=1, id="source", resources=[
                dict(source="a.txt", target="_fig/a.txt", owner="managed"),
                dict(source="b.txt", target="_fig/b.txt", owner="managed"),
                dict(source="seed.yml", target="params.yml", owner="seed")])
            Content["resources"] = [{"from": x["source"], "to": x["target"], "ownership": x["owner"]}
                                     for x in Content["resources"]]
            Manifest.write_text(json.dumps(Content))
            Projects = [Root / "reference", Root / "candidate"]
            for Project in Projects:
                Project.mkdir()
                (Project / "params.yml").write_text("project seed")

            def compare(*args):
                Results = []
                for Binary, Project in zip((NGR_RESOURCE_REFERENCE, NGR_TEST_BIN), Projects):
                    Before = resourceSnapshot(Project)
                    DATA = subprocess.run([Binary, *map(str, args)], cwd=Project, capture_output=True, text=True)
                    if DATA.returncode and args[0] == "pull":
                        self.assertEqual(resourceSnapshot(Project), Before)
                    Results.append(DATA)
                self.assertEqual(Results[0].returncode, Results[1].returncode,
                                 Results[0].stderr + Results[1].stderr)
                self.assertEqual(Results[0].stdout, Results[1].stdout)
                self.assertEqual(resourceSnapshot(Projects[0]), resourceSnapshot(Projects[1]))

            compare("pull", "--from", Manifest, "--dry-run")
            compare("pull", "--from", Manifest)
            for Project, Name in zip(Projects, ("qrt.manifest.json", "manifest.json")):
                ManifestProject = Project / Name
                DATA = json.loads(ManifestProject.read_text())
                DATA["owner"] = dict(precise=1.12345678901234, empty={}, absent=None, array=["one"])
                ManifestProject.write_text(json.dumps(DATA))
            (Source / "a.txt").write_text("changed")
            compare("status", "--check")

            Content["artifacts"] = {"bad": {"alias": "bad"}}
            Manifest.write_text(json.dumps(Content))
            compare("pull", "--force")
            del Content["artifacts"]
            Manifest.write_text(json.dumps(Content))
            compare("pull")
            compare("pull", "--force", "_fig/a.txt")
            Content["resources"] = Content["resources"][1:]
            Manifest.write_text(json.dumps(Content))
            compare("pull", "--force")
            compare("status", "--check")


if __name__ == "__main__":
    unittest.main()
