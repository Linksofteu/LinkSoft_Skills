# Descriptions and Evals

Use this reference when writing or tuning a skill description, or when adding eval assets.

## Description rules

- Write for triggering, not for marketing.
- Focus on user intent and when the skill should activate.
- Prefer imperative phrasing such as `Use this skill when...`.
- Include both the task and the likely prompt contexts.
- Stay concise; the spec allows up to 1024 characters, but shorter is usually better.

Good pattern:

```yaml
description: Use this skill when reviewing or improving Agent Skills, including naming, descriptions, references, scripts, evals, and repository compliance.
```

Weak patterns:

- `Helps with skills.`
- `This skill uses references and evals to improve outcomes.`

The first is too vague. The second describes internals rather than user intent.

## Trigger evaluation

When a description needs tuning, create a small eval set with:

- should-trigger queries
- should-not-trigger queries

Use realistic prompts with varied phrasing, explicit and implicit requests, and near-miss negatives.

## Train and validation splits

When the eval set grows beyond a quick manual check, split it into:

- a train set used to guide description changes
- a validation set used to check whether those changes generalize

Keep both sets mixed with should-trigger and should-not-trigger queries. Use the train set to decide what to revise, and reserve the validation set for checking whether the revised description holds up on prompts it was not tuned against.

## Run queries multiple times

Triggering can be nondeterministic, so do not rely on a single run per query when you need confidence.

- Run each query multiple times when practical.
- Judge should-trigger queries by whether they trigger more often than not.
- Judge should-not-trigger queries by whether they stay below that threshold.

Think in terms of trigger rates, not single pass/fail outcomes.

## Avoid overfitting description changes

When a query fails, revise the description to address the general category of miss rather than copying keywords from that prompt into the description.

- If should-trigger queries fail, the description is often too narrow.
- If should-not-trigger queries fail, the description is often too broad.
- Adjust the scope boundary in a way that generalizes to similar prompts, not just the exact examples that failed.

## Check with fresh prompts

Once the description performs well on the train and validation sets, run a final sanity check with a few fresh prompts that were not part of the tuning loop.

- Include both should-trigger and should-not-trigger prompts.
- Use the fresh prompts to confirm that the description generalizes beyond the eval set you optimized against.

Good negatives are adjacent tasks, not unrelated ones.

Examples for a skill-writing skill:

- Should trigger: `Can you help me write a reusable Agent Skill for CSV cleanup?`
- Should trigger: `My skill description is too vague. Tighten it so it triggers correctly.`
- Should not trigger: `Write a Python script that cleans a CSV file.`
- Should not trigger: `Review this PR for bugs.`

Run queries multiple times if your agent is nondeterministic and compare trigger rates instead of single runs.

## Output-quality evals

Prefer `evals/evals.json` for machine-friendly evaluation.

Compare the current skill against a baseline where possible, such as no skill, a previous version, or another reasonable point of comparison.

Minimal pattern:

```json
{
  "skill_name": "my-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "...",
      "expected_output": "...",
      "files": [],
      "assertions": [
        "..."
      ]
    }
  ]
}
```

Write assertions that are observable and specific. Prefer concrete checks over vague quality judgments.

When evaluation becomes more structured, save grading results, timing data, and benchmark summaries so you can compare the skill and the baseline over time.

Use human review when important qualities are hard to reduce to assertions alone. Capture specific, actionable feedback rather than vague reactions.

Good assertions:

- `The skill proposes a lowercase hyphenated name that matches the folder name.`
- `The description uses 'Use this skill when' phrasing.`
- `The result includes eval guidance in evals/evals.json.`

Weak assertions:

- `The output is good.`
- `The answer sounds professional.`

## Iteration loop

Use this cycle:

1. Run the evals
2. Inspect failed assertions, false triggers, and human-review feedback
3. Tighten the description or instructions
4. Re-run the evals
5. Keep the best version, not necessarily the latest one

For more detail, follow:

- https://agentskills.io/skill-creation/optimizing-descriptions
- https://agentskills.io/skill-creation/evaluating-skills
