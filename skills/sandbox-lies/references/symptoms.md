# Symptoms: an odd Bash result and where it is explained

One row per thing seen in a Bash result, a denial or a listing. The hook
annotates the sandbox's own diagnostics as they occur; these are the ones it
leaves alone, or that arrive outside a tool result.

| Seen | What it is | Where |
|---|---|---|
| `rm` on a dotfile says the device or resource is busy; `git clean -f` warns it failed to remove one | A mask: a mount point in the sandboxed call's namespace, nothing on disk | [masks-and-gates.md](masks-and-gates.md#a-mask-that-outlives-its-command) |
| Zero-byte or character-device dotfiles, `.claude/*` entries, untracked in `git status` | Masks of some running sandboxed call; never delete, commit or report them | [masks-and-gates.md](masks-and-gates.md) |
| Masks still listed by an unsandboxed `git status` with nothing running | A leaked mask set; restart Claude Code | [masks-and-gates.md](masks-and-gates.md#a-mask-that-outlives-its-command) |
| A denial naming `auto mode classifier` | The permission classifier, not the sandbox; `dangerouslyDisableSandbox` does not lift it | [classifier-denials.md](classifier-denials.md) |
| *Logging/Audit Tampering*, *Auto Mode Bypass* | A write to a file a hook consumes | [classifier-denials.md](classifier-denials.md#denials-by-the-reason-the-classifier-names) |
| *external repo outside the trusted source control org* | A push to another repository or a submodule | [classifier-denials.md](classifier-denials.md#denials-by-the-reason-the-classifier-names) |
| *Create Public Surface* | A release or publish the user did not name | [classifier-denials.md](classifier-denials.md#denials-by-the-reason-the-classifier-names) |
| A benign compound denied, its parts allowed alone | Unsandboxed compounds reach the classifier | [escapes-and-costs.md](escapes-and-costs.md#cost-the-classifier-denies-benign-compounds-unpredictably) |
| A `set -e` script ran on past a failure | errexit is inert inside the tool's wrapper | [bash-tool-wrapper.md](bash-tool-wrapper.md#set--e-is-inert-inside-a-call) |
| A `grep` probe disagrees with a script's grep | `grep` typed into the tool is ugrep | [bash-tool-wrapper.md](bash-tool-wrapper.md#grep-typed-into-the-tool-is-ugrep) |
| A `!` command acted in the wrong directory; a push says `Everything up-to-date` with commits unpushed | The `!` shell shares the agent's working directory | [bash-tool-wrapper.md](bash-tool-wrapper.md#the-human-partners--shell-shares-the-agents-working-directory) |
| zellij answers that there is no active session | Its IPC socket, under `/tmp/zellij-<uid>/`, is outside the sandbox; rerun the call with `dangerouslyDisableSandbox: true` | this row |
| An empty sandboxed `ps` while a background task runs | The sandbox's PID namespace hides it | [background-tasks.md](background-tasks.md) |
