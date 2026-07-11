# Day 5 — The ecosystem & wiring jobs together

Everything today runs *inside* GitHub. There is no server to deploy to, nothing
to SSH into, and nothing that can fail on you in front of the class. That's the
point: after two days of infra pain, today is all logic.

## What's here

| File | Teaches |
| --- | --- |
| `.github/workflows/day5-pr-hygiene.yml` | Composing marketplace actions; SHA pinning |
| `.github/workflows/day5-release.yml` | Release automation on a tag |
| `.github/workflows/day5-wiring.yml` | `needs`, job `outputs`, dynamic matrix, secret masking, environment gate |
| `.github/workflows/reusable-quality.yml` | A reusable workflow (`workflow_call` inputs/outputs/secrets) |
| `.github/workflows/day5-uses-reusable.yml` | Calling that reusable workflow |
| `SHA-PINNING.md` | The tj-actions story and the evaluation checklist |

## One-time setup before class

1. Create the labels the labeler references: **docs**, **source**, **ci**
   (Issues → Labels). The size labeler creates its own `size/*` labels.
2. (Optional) Add a repo secret `DEPLOY_KEY` with any dummy value so students can
   watch it print as `***` in `day5-wiring.yml`.
3. (Optional) Create a `staging` environment (Settings → Environments) and add a
   required reviewer so the `promote` job pauses on a gate.

## Try it

- **Wiring:** push any change under `day5-ecosystem/**`, or run *Day 5 · Wiring
  jobs together* from the Actions tab (`workflow_dispatch`). Watch `plan` feed
  `test` and `package`.
- **PR hygiene:** open a PR that touches files here. It gets area + size labels
  and a sticky comment.
- **Release:** `git tag day5-v1.0.0 && git push origin day5-v1.0.0`.

## The one idea to leave with

A CI pipeline's real job ends at a **trustworthy, tagged artifact**. How that
artifact reaches a server is a *separate* decision — and SSH-push is the fragile
end of it. Tomorrow (capstone) we take the artifact all the way to a real cloud.
