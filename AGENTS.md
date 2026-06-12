## Coding style

Improve readability whenever you can:
- Avoid introducing small helpers that only make people wonder what it is.
- Avoid helpers that are only used once and are only a few lines.
- Repeat things if repeating makes reading easier.
- Make minimal changes possible, unless it can bring great benefits.

Use conventional commits.

## Workflow

For bug fixes, add or update a regression test that demonstrates the bug before
changing the implementation. The test should fail on the old behavior and pass
after the fix. If a regression test is not practical, explain why.

Prefer `debug_inspect` snapshot tests for behavior examples, and use direct
assertions when they make loops or many small cases easier to read.

Before committing or handing off MoonBit code changes, run `moon info`, then
`moon fmt`. Review any `pkg.generated.mbti` changes. Keep formatting-only and
generated interface updates in a separate final cleanup commit so maintainers can
rebase, preserve, or drop tooling churn without mixing it into behavioral
commits.

When fixing an earlier commit on the current PR branch, prefer
`git commit --fixup <commit>` followed by `git rebase -i --autosquash` to keep
history clean. Only rewrite commits that belong to the current branch; do not
rewrite shared base branches.

Before creating a fixup commit, inspect the target commit with `git show
<commit>` and make sure the staged diff belongs to that commit's intent. Stage
only relevant hunks, preferably with `git add -p`, and create separate fixup
commits for fixes that belong to different earlier commits. After autosquash,
review the rewritten commits and rerun the relevant checks.

## Change review

During and after modifications, ask:
- Is this change necessary?
- Is this change correct?
- Is this change minimal?

## Pull requests

When creating a new PR, update `CHANGELOG.md` following the Keep a Changelog
convention. Put entries under `## [Unreleased]` using the appropriate category:
`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, or `Security`.

After the PR is created, update the changelog entry with the PR number.

Keep changelog entries user-facing and behavior-focused. Avoid implementation
details unless they are important to users.
