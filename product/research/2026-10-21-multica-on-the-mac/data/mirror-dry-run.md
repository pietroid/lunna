| Issue | Kind | Queue state | Gate | Runs | Multica status |
|---|---|---|---|---|---|
| #1 | create | done | — | 5 | `done` |
| #3 | research | waiting | review | 1 | `in_review` |
| #5 | improve | done | — | 4 | `done` |
| #6 | improve | done | — | 1 | `done` |
| #10 | research | done | — | 2 | `done` |
| #12 | create | done | — | 5 | `done` |
| #14 | research | waiting | review | 4 | `in_review` |
| #15 | improve | failed | failed | 3 | `blocked` |
| #18 | research | next: start | — | 0 | `todo` |

First tick, nothing mirrored yet:

multica issue create --title "#1 Improvements" --status done --project Queue --description-stdin   # body + links · PR #2
multica issue metadata set <new-id> github_issue 1
multica issue create --title "#3 Use shorebird for instant deploy on mobile" --status in_review --project Queue --description-stdin   # body + links · PR #4
multica issue metadata set <new-id> github_issue 3
multica issue create --title "#5 Improve GitHub flow and RFCs" --status done --project Queue --description-stdin   # body + links · PR #7
multica issue metadata set <new-id> github_issue 5
multica issue create --title "#6 Improve flow of skills" --status done --project Queue --description-stdin   # body + links · PR #9
multica issue metadata set <new-id> github_issue 6
multica issue create --title "#10 Add Posthog integration" --status done --project Queue --description-stdin   # body + links · PR #11
multica issue metadata set <new-id> github_issue 10
multica issue create --title "#12 New structure for organization: artifacts." --status done --project Queue --description-stdin   # body + links · PR #13
multica issue metadata set <new-id> github_issue 12
multica issue create --title "#14 Open source alternatives to manage agents" --status in_review --project Queue --description-stdin   # body + links · PR #16
multica issue metadata set <new-id> github_issue 14
multica issue create --title "#15 General improvements to the workflow" --status blocked --project Queue --description-stdin   # body + links · PR #17
multica issue metadata set <new-id> github_issue 15
multica issue create --title "#18 Using multica self hosted and my Mac as server" --status todo --project Queue --description-stdin   # body + links
multica issue metadata set <new-id> github_issue 18

A later tick, where Multica already shows the right status: no commands.
