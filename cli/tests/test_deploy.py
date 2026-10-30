import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys


NGR_TEST_BIN = os.environ["NGR_TEST_BIN"]
NGR_TEST_ROOT = os.environ["NGR_TEST_ROOT"]

PROVIDER = '''#!/usr/bin/env python3
import json
from pathlib import Path
import sys
Store = Path("provider.json")
State = json.loads(Store.read_text())
Args = sys.argv[1:]
Status = 0
with Path("provider.log").open("a") as FILE:
    FILE.write(json.dumps(Args) + "\\n")
if Args[0] == "sites:list":
    print(json.dumps(State))
elif Args[0] == "sites:create":
    Name = Args[Args.index("--name") + 1]
    if any(x["name"] == Name for x in State):
        Status = 1
    else:
        State.append(dict(name=Name, id="33333333-3333-3333-3333-333333333333", account_slug="test"))
elif Args[0] == "deploy":
    Site = next((x for x in State if "--site=" + x["id"] in Args), {})
    if Site.get("uploadFails"):
        Status = 1
    else:
        print("mock upload")
elif Args[0] == "api":
    Data = json.loads(Args[Args.index("--data") + 1])
    if Args[1] == "getDnsZone":
        print(json.dumps(dict(dns_servers=["ns.example.invalid"])))
        sys.exit(0)
    Site = next((x for x in State if x["id"] == Data["site_id"]), None)
    if Site is None:
        sys.exit(1)
    if Site.get("fails") == Args[1]:
        Status = 1
    elif Args[1] == "getSite":
        print(json.dumps(Site))
    elif Args[1] == "updateSite":
        Site.update(Data["body"])
    elif Args[1] == "provisionSiteTLSCertificate":
        Site.update(ssl=True, force_ssl=True)
        if Site.get("tlsResponseLost"):
            Status = 1
    else:
        raise ValueError(Args)
else:
    raise ValueError(Args)
Store.write_text(json.dumps(State))
sys.exit(Status)
'''


class DeployTest(unittest.TestCase):
    def setUp(self):
        self.Directory = tempfile.TemporaryDirectory(dir=NGR_TEST_ROOT)
        self.addCleanup(self.Directory.cleanup)
        self.Root = Path(self.Directory.name)
        Bin = self.Root / "mock-bin"
        Bin.mkdir()
        if os.name == "nt":
            (Bin / "netlify.py").write_text(PROVIDER)
            (Bin / "netlify.cmd").write_text(f'@echo off\n"{sys.executable}" "%~dp0netlify.py" %*\nexit /b %errorlevel%\n')
            (Bin / "dig.cmd").write_text("@echo off\necho 192.0.2.1\n")
        if os.name != "nt":
            (Bin / "netlify").write_text(PROVIDER)
            (Bin / "netlify").chmod(0o755)
            (Bin / "dig").write_text("#!/bin/sh\necho 192.0.2.1\n")
            (Bin / "dig").chmod(0o755)
        self.Env = dict(os.environ, PATH=str(Bin) + os.pathsep + os.environ["PATH"])
        self.Sites = [dict(name="test-one", id="11111111-1111-1111-1111-111111111111", account_slug="test", dns_zone_id="zone"), dict(name="test-two", id="22222222-2222-2222-2222-222222222222", account_slug="test")]
        (self.Root / "provider.json").write_text(json.dumps(self.Sites))
        for Name in ("one", "two"):
            (self.Root / "html" / Name).mkdir(parents=True)
            (self.Root / "html" / Name / "index.html").write_text(Name)
        self.Artifacts = [dict(alias=x, kind="static", path=f"html/{x}", siteSlug=f"test-{x}", domain=f"{x}.example.invalid", required=True) for x in ("one", "two")]
        self.writeManifest()

    def writeManifest(self):
        (self.Root / "manifest.json").write_text(json.dumps(dict(schemaVersion=2, artifacts=self.Artifacts)))

    def runCli(self, *args, expected=0):
        DATA = subprocess.run([NGR_TEST_BIN, "deploy", *args], cwd=self.Root, env=self.Env, capture_output=True, text=True)
        self.assertEqual(DATA.returncode, expected, DATA.stdout + DATA.stderr)
        return DATA

    def calls(self):
        FILE = self.Root / "provider.log"
        return [json.loads(x) for x in FILE.read_text().splitlines()] if FILE.exists() else []

    def testRegistrationUploadTlsAndUnbind(self):
        self.runCli("init", "one", "TEST-ONE", "--account", "TEST")
        self.runCli("one", "html/one")
        self.runCli("one", "html/one", "--prod")
        Calls = [x for x in self.calls() if x[0] == "deploy"]
        self.assertNotIn("--prod", Calls[0])
        self.assertIn("--prod", Calls[1])
        self.assertIn("--no-build", Calls[1])
        self.runCli("domain", "one", "one.example.invalid", "--https")
        DATA = json.loads((self.Root / "provider.json").read_text())
        self.assertEqual(DATA[0]["custom_domain"], "one.example.invalid")
        self.assertTrue(DATA[0]["ssl"])
        self.runCli("domain", "one", "different.example.invalid", expected=1)
        self.runCli("domain", "one", "different.example.invalid", "--rebind")
        self.runCli("unbind", "one")
        self.assertNotIn("one=", (self.Root / ".netlify/sites.env").read_text())
        self.assertEqual(len(json.loads((self.Root / "provider.json").read_text())), 2)

    def testManifestDryRunAndBatch(self):
        self.runCli("init", "--manifest", "manifest.json", "--dry-run")
        self.assertEqual(self.calls(), [])
        self.runCli("init", "--manifest", "manifest.json")
        Before = self.calls()
        self.runCli("--manifest", "manifest.json", "--dry-run", "--prod")
        self.runCli("domain", "--manifest", "manifest.json", "--dry-run", "--https")
        self.assertEqual(self.calls(), Before)
        self.runCli("--manifest", "manifest.json", "--only", "two", "--prod")
        self.assertEqual(len([x for x in self.calls() if x[0] == "deploy"]), 1)
        self.runCli("domain", "--manifest", "manifest.json", "--except", "one", "--https")
        DATA = json.loads((self.Root / "provider.json").read_text())
        self.assertNotIn("custom_domain", DATA[0])
        self.assertEqual(DATA[1]["custom_domain"], "two.example.invalid")

    def testPreflightAndClaimConflicts(self):
        self.runCli("init", "--manifest", "manifest.json")
        (self.Root / "html/two/index.html").unlink()
        self.runCli("--manifest", "manifest.json", expected=1)
        self.assertFalse(any(x[0] == "deploy" for x in self.calls()))
        self.Artifacts[1]["siteSlug"] = self.Artifacts[0]["siteSlug"]
        self.writeManifest()
        Before = self.calls()
        self.runCli("init", "--manifest", "manifest.json", "--only", "one", expected=1)
        self.assertEqual(self.calls(), Before)

    def testUploadResponsesAreResultsAndPartialPublicationIsRecorded(self):
        self.runCli("init", "--manifest", "manifest.json")
        for Flags in ((), ("--quiet",)):
            with self.subTest(flags=Flags):
                DATA = self.runCli(*Flags, "one", "html/one")
                self.assertEqual(DATA.stdout, "mock upload\n")
                self.assertNotIn("mock upload", DATA.stderr)
        self.Sites[1]["uploadFails"] = True
        (self.Root / "provider.json").write_text(json.dumps(self.Sites))
        # The upload of one completed before two failed: its response stays a result and the error names both.
        DATA = self.runCli("--manifest", "manifest.json", expected=1)
        self.assertEqual(DATA.stdout, "mock upload\n")
        self.assertIn("uploaded: one", DATA.stderr)
        self.assertIn("not uploaded: two", DATA.stderr)
        # A failure before any completed upload is the provider's error alone.
        DATA = self.runCli("--manifest", "manifest.json", "--only", "two", expected=1)
        self.assertEqual(DATA.stdout, "")
        self.assertNotIn("uploaded:", DATA.stderr)

    def testPartialRegistrationIsRecorded(self):
        # The site name test-elsewhere is taken in another account, so the provider refuses to create it for test.
        self.Sites.append(dict(name="test-elsewhere", id="44444444-4444-4444-4444-444444444444", account_slug="other"))
        (self.Root / "provider.json").write_text(json.dumps(self.Sites))
        self.Artifacts[1]["siteSlug"] = "test-elsewhere"
        self.writeManifest()
        # one was registered before the creation for two failed: the record is a result and the error names both.
        DATA = self.runCli("init", "--manifest", "manifest.json", "--create", "--account", "test", expected=1)
        self.assertEqual(DATA.stdout, "one\tregistered\t11111111-1111-1111-1111-111111111111\n")
        self.assertIn("registered: one\nnot registered: two", DATA.stderr)
        self.assertEqual((self.Root / ".netlify/sites.env").read_text(), "one=11111111-1111-1111-1111-111111111111\n")
        # A failure before any effect is the provider's error alone.
        DATA = self.runCli("init", "--manifest", "manifest.json", "--only", "two", "--create", "--account", "test", expected=1)
        self.assertEqual(DATA.stdout, "")
        self.assertNotIn("registered:", DATA.stderr)
        # The provider creates test-new in the account test, so the lookup in other fails after the creation.
        DATA = self.runCli("init", "new", "test-new", "--create", "--account", "other", expected=1)
        self.assertEqual(DATA.stdout, "new\tcreated\ttest-new\n")
        self.assertIn("created: new\nnot registered: new", DATA.stderr)

    def testPartialDomainConfigurationIsRecorded(self):
        self.runCli("init", "--manifest", "manifest.json")
        self.Sites[1]["fails"] = "provisionSiteTLSCertificate"
        (self.Root / "provider.json").write_text(json.dumps(self.Sites))
        # one was configured and two bound before its certificate failed: the record is a result and the error names both.
        DATA = self.runCli("domain", "--manifest", "manifest.json", "--https", expected=1)
        self.assertEqual(DATA.stdout, "one\tbound\tone.example.invalid\none\thttps\tone.example.invalid\n"
                                      "two\tbound\ttwo.example.invalid\n")
        self.assertIn("bound: one, two\nhttps: one\nnot configured: two", DATA.stderr)
        # A failure before any effect is the provider's error alone.
        self.Sites[1]["fails"] = "updateSite"
        (self.Root / "provider.json").write_text(json.dumps(self.Sites))
        DATA = self.runCli("domain", "--manifest", "manifest.json", "--only", "two", expected=1)
        self.assertEqual(DATA.stdout, "")
        self.assertNotIn("configured:", DATA.stderr)

    def testCreateAndRetargetProtection(self):
        self.runCli("init", "new", "test-new", "--create", "--account", "test")
        self.assertIn("33333333", (self.Root / ".netlify/sites.env").read_text())
        self.runCli("init", "new", "test-one", expected=1)
        self.assertIn("33333333", (self.Root / ".netlify/sites.env").read_text())

    def testRegistryPreservationAndTlsReconciliation(self):
        (self.Root / ".netlify").mkdir()
        Registry = self.Root / ".netlify/sites.env"
        Registry.write_text("# owner comment\nOTHER=value\none=\n")
        self.runCli("init", "one", "test-one")
        self.Sites[0]["tlsResponseLost"] = True
        (self.Root / "provider.json").write_text(json.dumps(self.Sites))
        self.runCli("domain", "one", "one.example.invalid", "--https")
        State = json.loads((self.Root / "provider.json").read_text())
        self.assertTrue(State[0]["ssl"] and State[0]["force_ssl"])
        self.runCli("unbind", "one")
        self.assertEqual(Registry.read_text(), "# owner comment\nOTHER=value\n")

    def testDomainPreflightAndOptionalUnregisteredOutput(self):
        self.runCli("init", "--manifest", "manifest.json")
        self.Sites[1]["custom_domain"] = "different.example.invalid"
        (self.Root / "provider.json").write_text(json.dumps(self.Sites))
        Before = self.calls()
        self.runCli("domain", "--manifest", "manifest.json", expected=1)
        Calls = self.calls()[len(Before):]
        self.assertFalse(any(x[0:2] == ["api", "updateSite"] for x in Calls))
        self.runCli("unbind", "two")
        (self.Root / "html/two/index.html").unlink()
        self.Artifacts[1]["required"] = False
        self.writeManifest()
        self.runCli("--manifest", "manifest.json")
        self.assertEqual(len([x for x in self.calls() if x[0] == "deploy"]), 1)


if __name__ == "__main__":
    unittest.main()
