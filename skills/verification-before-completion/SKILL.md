---
name: verification-before-completion
description: Use before claiming work is complete, fixed, or passing, and before committing or opening a PR. Requires running the proving command fresh and reading its output before any success claim. Evidence before assertions.
---

# Verification Before Completion

**Core principle:** evidence before claims, always. Violating the letter of this rule is violating its spirit.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If the verification command did not run in this turn, you cannot claim it passes. A previous run, a plausible-looking diff, or a subagent's report is not evidence.

## The Gate

Before stating any status, or any wording that implies success:

1. **Identify** the command that proves the claim.
2. **Run** it, fresh and complete. No partial runs, no cached results.
3. **Read** the full output: exit code, failure count, the actual numbers.
4. **Compare** output to the claim. If it does not confirm the claim, report the actual state with the evidence. If it does, make the claim with the evidence.
5. If verification is impossible right now, say exactly what was not verified. That is a status report, not a completion claim.

## What each claim requires

| Claim | Requires | Not sufficient |
|---|---|---|
| Tests pass | Test command output, 0 failures, this turn | Earlier run, "should pass", linter clean |
| Build succeeds | Build command, exit 0 | Linter passing, logs look fine |
| Bug fixed | Original symptom reproduced, then shown gone | Code changed, assumed fixed |
| Regression test works | Red-green: test fails with the fix reverted, passes with it restored | Test passes once |
| Subagent or workflow finished | `git diff --stat` shows the changes, and the checks above run by you | Agent reports "success" |
| Requirements met | Line-by-line checklist against the plan or ticket | Tests passing |
| Safe to merge | Diff reviewed against the ticket scope, tests run on the merged state | "No conflicts" |

## Red flags

Stop and run the gate when you notice any of these in your own draft:

- "should", "probably", "seems to", "looks correct"
- "Done", "Fixed", "Great", or any satisfaction before the command ran
- About to commit, push, or open a PR without a fresh test run
- Repeating a subagent's success report as your own finding
- Treating a partial check (one module, one case) as proof for the whole

## Patterns

**Tests:** run the test command, read `N/N passed`, then say "all N tests pass". Not "should pass now".

**Regression test (red-green):** write the test, run it (pass), revert the fix, run it (must fail), restore the fix, run it (pass). Report all three results. A test that was never seen failing proves nothing.

**Delegated work:** the agent says done. Check the diff, run the tests yourself, then report what you verified. Trust nothing you did not see.

**Requirements:** re-read the ticket or plan, make a checklist, verify each item, report gaps explicitly.

## When this applies

Before every success or completion claim, every expression of satisfaction, every commit, PR, "moving on to the next step", and every hand-off to or from an agent. It applies to exact phrases, paraphrases, and implications alike.
