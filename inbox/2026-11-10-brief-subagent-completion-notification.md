# Brief: a subagent does receive the completion notification

From a gitlore session's memory index audit, 2026-11-10.

`skills/sandbox-lies/references/background-tasks.md:14` says a "completion
notification may never reach a subagent, so it is never the only thing waited
on" (still so at the 0.3.0 release commit).

Two sources say otherwise:

- The ddaanet memory fact `cc-bash-background-no-duration-cap`, read from a
  sidechain JSONL on CC 2.1.282: the subagent gets a `queued_command`
  attachment with `commandMode: task-notification`. What stalls a subagent is
  a watcher of its own that it idles on with the notification already in hand.
- My human partner, 2026-11-10: lost completion notifications have been fixed.

`shared-claude.md` already tells an executor to wait for the notification and
build no watcher, so the skill is the one text prescribing the opposite.

Proposed: re-probe on the current CC version, then drop or reword the
sentence. Not verified here beyond reading the two texts.
