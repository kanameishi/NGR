# Recipe evidence

Use this recorded coverage when recommending commands or explaining whether a
recipe has been accepted. The command shares the version of the NGR package.
The records establish the operations and limits below, not every form documented in
the operation references. Project-specific acceptance supplied for the task
can establish additional coverage. If no matching acceptance is available,
label that part of the proposed recipe as unverified for the requested scope;
do not substitute help or start a render/deploy to create evidence for a
commands-only request.

## Executed scoped pull and direct HTML render

On 2026-09-22 the installed `ngr` resolved through `/usr/local/bin`; the
recorded build was `backup-before-typewriter-height-224-ga18dfec-dirty`.
From the `agents` checkout, outside the isolated fixture project, these
operations each exited 0. Here `<fixture>` abbreviates the recorded project
`agents/dev/SoT/skills-promotion-20260922/workflows/ngr`, not a user input:

```text
ngr --root <fixture> pull --from ngr styles yml lua
ngr --root <fixture> render report.qmd --profile html
```

The final `html/report/index.html` contains fixture IDs T01/T02, values
12.50/7.25 and sum 19.75. The recorded browser check covered ten local assets,
the table, layout at 1280×720 and TOC navigation. Final HTML SHA256:
`6632c0a7d983bc74e0e67fd470e255b98b463f3bfe9ddc1eebce6c19d5852bd9`.
This accepts one synthetic direct HTML delivery with explicit root. It does
not establish manifest rendering, books, DOCX, slides, widgets, publication or
scientific content acceptance.

Audit identity: `agents/dev/SoT/skills-promotion-20260922/workflows/`,
`CLI-IDENTITIES.md`, `OBSERVED.json`, `REVIEW.md`, and
`ngr/{pull,render}.result.json`, `ngr/BROWSER-QA.md`.

## Root routing and plans

The recorded source-payload tests `testRootTransportsResourcesChecksAndPlans`
and `testCwdAndInvalidRoots` passed (2 tests, 6.751 seconds). They covered
resource pull/status/doctor, manifest render and deploy-init plans,
relative/absolute roots with spaces, cwd invocation and invalid roots.
These tests establish route transport and plans. They did not execute real
renders or contact Netlify; they do not establish a client book recipe.

Audit identity: `NGR/dev/plan/cli-root/RESULTS.md` and
`NGR/dev/SoT/cli-root/candidate.log`; accepted source payload SHA256
`108dc344eb85494de672662404c4edb37f6d302c2c9fc32136a607c9c2442347`.

## Commands-only decision coverage

A separate simulated request selected `report.en,toc` in `manifest.json`,
execution from the project directory, and then explicitly selected production.
The evaluator proposed `ngr render --manifest manifest.json --only report.en,toc`
and `ngr deploy --manifest manifest.json --only report.en,toc --prod`.
Neither command ran. The case covers preservation of supplied choices and
asking for absent publication mode; it is not execution or deploy acceptance.

Audit identity:
`agents/dev/SoT/skills-promotion-20260922/workflows/NGR-COMMANDS-ONLY.md`.

These audit locators identify the retained release evidence. Reading producer
checkouts or retrieving those archives is not a consumer prerequisite; this
reference carries their usable coverage and limits with the installed skill.
