# Background tasks are invisible to a sandboxed `ps`

A sandboxed Bash call runs in its own PID namespace, so its `ps` lists only that
call's processes: a `run_in_background` task, with everything it spawns, is
absent from it. An unsandboxed `ps` lists it. Checked 2026-09-27 on CC 2.1.281:
with a sandboxed `sleep` running in the background, `ps -eo pid,args` returned 5
lines and no `sleep` sandboxed, and 204 lines with the `sleep` unsandboxed.
Earlier, a `ps` showed two `bash` entries while a background test suite was
mid-run and went on to complete (2026-08-15, CC version not recorded). An empty
sandboxed `ps` is not evidence that a background job died. Restarting the work
in the foreground to check puts two heavy runs on the box; the second times out,
and both then look like the first one failing. Check with an unsandboxed `ps`,
and watch the task's output file and the artifact the job writes on success; a
completion notification may never reach a subagent, so it is never the only
thing waited on. Key a wait on the command's exit, not on an output line that
reads as terminal.
