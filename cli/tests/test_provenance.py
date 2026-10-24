import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


NGR_TEST_BIN = os.environ["NGR_TEST_BIN"]
NGR_TEST_ROOT = os.environ["NGR_TEST_ROOT"]
NGR_REFERENCE_BIN = os.environ.get("NGR_REFERENCE_BIN")
NGR_REFERENCE_LIBRARY = os.environ.get("NGR_REFERENCE_LIBRARY")


class ProvenanceTest(unittest.TestCase):
    def testInstalledAPI(self):
        with tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT) as DIR:
            Root = Path(DIR)
            subprocess.run([NGR_TEST_BIN, "pull", "--from", "ngr", "yml", "lua", "styles"],
                           cwd=Root, check=True, stdout=subprocess.DEVNULL)
            shutil.copy2(Path(__file__).resolve().parents[2] / "lib/tests/testthat/test-quartoRenderStamp.R",
                         Root / "checks.R")
            (Root / "checks.qmd").write_text(
                '---\ntitle: Installed provenance API\n---\n\n```{r}\n'
                'NGR::quartoRenderStamp(list())\n'
                'testthat::test_file("checks.R", stop_on_failure = TRUE)\n```\n',
                encoding="utf-8")
            DATA = subprocess.run([NGR_TEST_BIN, "render", "checks.qmd", "--profile", "html"],
                                  cwd=Root, capture_output=True, text=True)
            self.assertEqual(DATA.returncode, 0, DATA.stdout[-2000:] + DATA.stderr[-6000:])
            self.assertTrue((Root / "html/checks/index.html").is_file())

    def testPublicStampParityAndFailures(self):
        with tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT) as DIR:
            Root = Path(DIR) / "candidate"
            Root.mkdir()
            subprocess.run([NGR_TEST_BIN, "pull", "--from", "ngr", "yml", "lua", "styles"],
                           cwd=Root, check=True, stdout=subprocess.DEVNULL)
            (Root / "page.qmd").write_text("---\ntitle: Provenance\n---\n\nStamp sentinel.\n",
                                          encoding="utf-8")
            (Root / "chapter.qmd").write_text("preserved chapter\n", encoding="utf-8")
            Entry = dict(commit="abcdef0123456789", dirty=False,
                         md5=hashlib.md5((Root / "chapter.qmd").read_bytes()).hexdigest())
            Source = dict(complete=True, files={"chapter.qmd": Entry})
            Binaries = [(NGR_TEST_BIN, Root, "manifest.json")]
            if NGR_REFERENCE_BIN:
                Reference = Path(DIR) / "reference"
                shutil.copytree(Root, Reference)
                (Reference / "manifest.json").rename(Reference / "qrt.manifest.json")
                # Each tool stamps through its own filters; their stamp variables differ.
                subprocess.run([NGR_REFERENCE_BIN, "init", "--force", "lua"], cwd=Reference,
                               check=True, capture_output=True)
                Binaries.append((NGR_REFERENCE_BIN, Reference, "qrt.manifest.json"))
            Cases = (
                # The stamp carries the print date alone since 9683449; the three
                # provenance states render and stamp the same way.
                ("clean", {"book": Source}, r"^Printed: \d{2}/\d{2}/\d{4}$"),
                ("incomplete", {"book": dict(Source, complete=False)}, r"^Printed: \d{2}/\d{2}/\d{4}$"),
                ("unknown", {}, r"^Printed: \d{2}/\d{2}/\d{4}$"),
            )
            for Name, Scaffolds, Expected in Cases:
                with self.subTest(case=Name):
                    Stamps = []
                    for Binary, Project, Filename in Binaries:
                        (Project / Filename).write_text(json.dumps(dict(schemaVersion=2, artifacts=[], scaffolds=Scaffolds)))
                        Environment = os.environ.copy()
                        if Binary == NGR_REFERENCE_BIN and NGR_REFERENCE_LIBRARY:
                            Environment["R_LIBS"] = NGR_REFERENCE_LIBRARY
                        DATA = subprocess.run([Binary, "render", "page.qmd", "--profile", "html"],
                                              cwd=Project, capture_output=True, text=True, env=Environment)
                        self.assertEqual(DATA.returncode, 0, DATA.stderr[-5000:])
                        Output = Project / "html/page/index.html"
                        Stamp = re.search(r"Printed: [^<]+", Output.read_text(encoding="utf-8")).group()
                        self.assertRegex(Stamp, Expected)
                        Stamps.append(Stamp)
                    self.assertEqual(len(set(Stamps)), 1, Stamps)
            for Name, Files, Expected in (
                ("invalid", {"chapter.qmd": dict(Entry, md5="invalid")}, "Invalid scaffold provenance"),
                ("escape", {"../outside.qmd": Entry}, "Scaffold path escapes the project"),
            ):
                with self.subTest(case=Name):
                    for Binary, Project, Filename in Binaries:
                        (Project / Filename).write_text(json.dumps(dict(scaffolds={"book": dict(complete=True, files=Files)})))
                        Output = Project / "html/page/index.html"
                        Before = Output.read_bytes()
                        Environment = os.environ.copy()
                        if Binary == NGR_REFERENCE_BIN and NGR_REFERENCE_LIBRARY:
                            Environment["R_LIBS"] = NGR_REFERENCE_LIBRARY
                        DATA = subprocess.run([Binary, "render", "page.qmd", "--profile", "html"],
                                              cwd=Project, capture_output=True, text=True, env=Environment)
                        self.assertNotEqual(DATA.returncode, 0)
                        self.assertIn(Expected, DATA.stderr)
                        self.assertEqual(Output.read_bytes(), Before)
            self.assertEqual((Root / "chapter.qmd").read_text(), "preserved chapter\n")


if __name__ == "__main__":
    unittest.main()
