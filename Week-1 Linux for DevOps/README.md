# Linux for DevOps — Practice Kit

Hands-on drills to go with the **Day 1 (Filesystem & Editors)** and **Day 3
(Text Processing)** material. Clone or copy this folder onto the practice box.

```
practice/
├── vim/                      # editor drills
│   ├── README.md
│   ├── vim_practice.txt      # jumps & search  (search with your fingers)
│   └── vim_edit.conf         # operator + motion editing  (aim, then act)
└── text-processing/          # grep / sed / awk / cut / jq / yq
    ├── README.md             # the "Orbit" dataset + schemas
    ├── users.csv
    ├── app.log
    ├── nginx_access.log
    ├── services.json
    ├── config.yaml
    ├── EXERCISES.md          # 38 graded problems  (hand this to students)
    └── SOLUTIONS.md          # verified answer key  (keep for yourself)
```

## Suggested flow

- **Vim day:** everyone opens `vim/vim_practice.txt`, arrows banned, races through
  the ten jump drills; then `vim_edit.conf` for the editing drills. ~20 min.
- **Text-processing day:** start in `text-processing/`, read the README so the
  dataset makes sense, then work `EXERCISES.md` Parts 1→7. The five files describe
  **one** system, so Part 7 has them correlate a 500 in the access log to the
  unhealthy service in the JSON — the real on-call motion.

## Tooling note

`jq` and **mikefarah's** `yq` (the Go one) are needed for Parts 5–6 — both are in
the classroom devcontainer. The CSV trap in Part 2 (#11) is best fixed with GNU
`awk` (`FPAT`) or a `python3 -c` one-liner; a plain comma split gives wrong
answers, which is the lesson.

Every command in `SOLUTIONS.md` was run against these exact files — the expected
outputs are real, not illustrative.
