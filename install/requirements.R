# DOCX also needs lxml in python3 (python on Windows). Provision it explicitly
# with that interpreter's -m pip install lxml; see cli/README.md. Render checks
# the module before Quarto, but loading NGR and other profiles do not require it.
list(command = "ngr", exports = c("pullResources", "compareResources", "checkResources", "quartoRender", 
    "quartoRenderManifest", "netlifyRegister", "netlifyDeploy", "netlifyDomain", "netlifyUnbind", "netlifyRegisterManifest", 
    "netlifyDeployManifest", "netlifyDomainManifest"), packages = character(), tools = "quarto", optional = "python3", 
    buildInfo = "scaffold/BUILD_INFO", pathEnv = "NGR_COMMAND_PATH",
    documentWriters = c("showTypewriter", "rotateTypewriter", "showASCII", "showCode", "showHTML", "showGithubREADME",
        "showMarkdownRendered", "showPDF", "knitBlock"))
