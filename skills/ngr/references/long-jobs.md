# Long renders and resumption

Use the normal execution session when it can remain attached. If the selected
job must survive disconnection, use an available persistent session mechanism
such as tmux, or nohup with a completion record. NGR has no detached mode or
universal timeout. Detachment does not survive host shutdown.

Resolve the exact native `ngr render` command through [Render](render.md).
Record the project root, source/profile or manifest selection, input generation,
destination, process/session identity, stdout/stderr log and the command's final
exit status. A PID or queue launch is only a launch result. Give each attempt
distinct records so an old success cannot be mistaken for the current result.
With nohup, a separate completion marker must capture startup failure as well
as NGR's exit; after reconnection, a vanished PID without that record remains
unknown.

Keep inputs stable while consumed. Require the user's explicit validation of
concurrency and resource limits before a concurrent launch; available resources
do not select those values. Ask and wait for missing choices. Check that the
validated budget allows the launch and writes are independent: jobs must not
replace a shared output or modify resources another render needs. A native
manifest batch is sequential and stops at its first render failure; putting
it in another queue does not change that behavior.

On resume, inspect the recorded process and bounded log/completion records
before launching anything. Elapsed time alone does not justify killing or
duplicating a render. If it ended, reconcile final status with the delivered
outputs and classify completed, failed, unattempted and unknown aliases.
Preserve verified successes and continue only the unfinished authorized scope.

The batch's closing note `manifest complete` on stderr, or its exit status 0
when `--quiet` hides that note, indicates it passed its output existence checks.
Apply the requested content and visual QA to the final tree before declaring
the product accepted or performing a requested deploy.
