# Triage Labels

The skills speak in terms of five canonical triage roles. Plane has per-project labels
(`Bug`, `Feature`, `Improvement`, `Decision`, `Blocked`, `Next`) and named states, so
each role maps to a state, a label, or both.

| Role in mattpocock/skills | In our Plane project                                 | Meaning                                  |
| ------------------------- | ---------------------------------------------------- | ---------------------------------------- |
| `needs-triage`            | state `Backlog`, no class label yet                  | Maintainer needs to evaluate this issue  |
| `needs-info`              | label `Blocked`, plus a comment naming what's missing | Waiting on reporter for more information |
| `ready-for-agent`         | state `Todo`                                         | Fully specified, ready for an AFK agent  |
| `ready-for-human`         | state `Todo` plus label `Decision`                   | Requires Ryan's judgment or hands        |
| `wontfix`                 | state `Cancelled`                                    | Will not be actioned                     |

Category roles: `bug` is label `Bug`; `enhancement` is `Feature` (new behaviour) or
`Improvement` (better existing behaviour).

`Next` is not a triage role. It marks the one work item to do next in the project.

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), apply the
corresponding state or label from this table.
