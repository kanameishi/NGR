runCommand(Launcher, c("pull", "--from", "ngr", "bib/apa.csl"))
runCommand(Launcher, c("status", "--check", "bib/apa.csl"))
stopifnot(identical(unname(tools::md5sum("bib/apa.csl")),
                    unname(tools::md5sum(file.path(Prefix, "libexec/ngr/scaffold/bib/apa.csl")))))
# doctor reports the five required checks and the optional tools; a changed file of the receipt fails it with exit 1.
Report <- jsonlite::fromJSON(paste(runCommand(Launcher, "doctor"), collapse = "\n"), simplifyVector = FALSE)
stopifnot(identical(Report$summary$status, "ok"),
          identical(vapply(Report$checks, `[[`, character(1L), "name"),
                    c("library", "exports", "packages", "tools", "receipt", "optional")),
          identical(vapply(Report$checks, `[[`, logical(1L), "required"), c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE)))
Stamp <- file.path(Prefix, "libexec", Runtime, "BUILD_INFO")
Original <- readBin(Stamp, "raw", file.size(Stamp))
write("changed=after installation", Stamp, append = TRUE)
Report <- tryCatch(jsonlite::fromJSON(paste(runCommand(Launcher, "doctor", status = 1L), collapse = "\n"), simplifyVector = FALSE),
                   finally = writeBin(Original, Stamp))
stopifnot(identical(Report$summary$status, "fail"), identical(Report$checks[[5L]]$status, "fail"))
