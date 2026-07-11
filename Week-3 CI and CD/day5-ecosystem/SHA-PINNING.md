# Why we pin actions to a commit SHA (the tj-actions story)

Every third-party action in this day's workflows is pinned like this:

```yaml
uses: actions/labeler@8558fd74291d67161a8a78ce36a881fa63b766a9 # v5.0.0
```

Not like this:

```yaml
uses: actions/labeler@v5   # convenient, and a moving target
```

## The reason, in one incident

In March 2025, `tj-actions/changed-files` — an action used by over 23,000
repositories — was compromised. Attackers didn't just push malicious code; they
**rewrote the existing version tags** so that `@v44`, `@v45`, etc. all pointed at
a commit that dumped the runner's secrets into the workflow logs. On public
repos, those logs were readable by anyone.

Sit with the implication for a second:

- If you pinned to a **tag** (`@v44`), the tag was moved out from under you. You
  were running the malicious code without changing a line of your workflow.
- If you pinned to a **full commit SHA**, you were unaffected — a SHA is
  immutable; there is no way to point it at different code.

The same wave hit the `reviewdog` org's actions (a separate CVE) around the same
time. That is exactly why, in `day5-pr-hygiene.yml`, we use official/first-party
actions for the sensitive steps and pin *everything* to a SHA.

## The evaluation checklist (teach this before "go shopping")

Before you add any action to a workflow that can see your secrets:

1. **Who publishes it?** Prefer verified creators and first-party (`actions/*`).
2. **How widely used is it?** Marketplace usage count and stars are a weak but
   real signal.
3. **What permissions does it demand?** An action that only formats code should
   not need `contents: write`.
4. **Pin it to a full commit SHA.** Add the human-readable tag as a trailing
   comment so you (and Dependabot) know what version the SHA represents.
5. **Let a bot bump it.** Dependabot and tools like `pinact`/`ratchet` update the
   SHA *and* the comment together, so pinning doesn't mean going stale.

## How to get the SHA for a tag

```bash
# The dereferenced commit SHA for a given tag:
git ls-remote --tags https://github.com/actions/labeler.git 'refs/tags/v5*'
```

Take the line ending in `^{}` (the commit the tag points at) for annotated tags,
or the plain ref line for lightweight tags. Or just open the action's release on
GitHub and copy the commit SHA. Dependabot's `github-actions` ecosystem will keep
these current for you automatically.
