# Git & Version Control Systems

## 1. Core Concepts & Architecture

### Q1: Explain the three main states (and areas) in Git.
* **Answer:**
  1. **Working Directory:** The local directory on your filesystem where you actively edit files.
  2. **Staging Area (Index):** A staging file/area that tracks changes that will be included in the next commit. Modified files are moved here using `git add`.
  3. **Repository (`.git` / Commit History):** The permanent history stored as immutable snapshot objects (commits, trees, blobs) in the `.git` database.
  *(Bonus: The Remote Repository refers to the hosted version like GitHub, GitLab, or Bitbucket).*

---

### Q2: What is the difference between `git merge` and `git rebase`? When would you use each?
* **Answer:**
  * **`git merge`:**
    - Creates a new "merge commit" combining the histories of two branches.
    - Preserves the exact historical timeline and branch context.
    - Non-destructive; safe for shared public branches.
  * **`git rebase`:**
    - Moves or reapplies a sequence of commits from one branch on top of another base commit.
    - Rewrites commit history to create a clean, linear project history.
    - **Golden Rule:** Never rebase public/shared branches, as it rewrites commit hashes and causes synchronization conflicts for teammates.
* **When to use:** Use `git rebase` on local feature branches before opening a PR to keep commit history clean; use `git merge` (or Squash & Merge via PR) when integrating feature branches into `main`.

---

### Q3: What is the difference between `git pull` and `git fetch`?
* **Answer:**
  * `git fetch`: Downloads new commits, branches, and tags from the remote repository into your local `.git` repository, but **does not modify** your working directory or merge into your current branch. It updates remote tracking branches (e.g., `origin/main`).
  * `git pull`: Performs a `git fetch` immediately followed by a `git merge` (or `git rebase` if configured with `--rebase`) of the remote branch into the currently checked-out branch.

---

### Q4: Explain the differences between Git branching strategies: Gitflow vs. Trunk-Based Development.
* **Answer:**
  * **Gitflow:**
    - Uses multiple long-lived branches: `main` (production), `develop` (integration), plus short-lived `feature/*`, `release/*`, and `hotfix/*` branches.
    - Best suited for traditional software release cycles with scheduled versioning.
  * **Trunk-Based Development:**
    - Developers collaborate on a single branch ("trunk" or `main`) with short-lived feature branches merged frequently (often multiple times a day).
    - Relies heavily on automated CI tests and Feature Flags.
    - **Standard in DevOps / CI/CD** because it reduces merge hell and enables rapid, continuous delivery.

---

## 2. Practical Commands & Troubleshooting Scenarios

### Q5: How do you resolve a Git merge conflict? Walk through the steps.
* **Answer Steps:**
  1. Identify conflicting files via `git status`.
  2. Open conflicting files and locate the conflict markers:
     ```text
     <<<<<<< HEAD (Current change)
     echo "Environment: Staging"
     =======
     echo "Environment: Production"
     >>>>>>> feature-branch (Incoming change)
     ```
  3. Edit the file to select the correct code, removing all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
  4. Stage the resolved files: `git add <filename>`.
  5. Finalize the merge commit: `git commit -m "Resolve merge conflict in config"`.
  6. Run automated tests to verify functionality before pushing.

---

### Q6: What is the difference between `git reset` (soft, mixed, hard) and `git revert`?
* **Answer:**
  * **`git reset`** (Moves `HEAD` backward in history):
    - `--soft`: Moves `HEAD` back; leaves changes in the **Staging Area**.
    - `--mixed` (default): Moves `HEAD` back; leaves changes in the **Working Directory** (unstaged).
    - `--hard`: Moves `HEAD` back; **discards all working directory and staged changes**. Dangerous!
  * **`git revert <commit-hash>`:**
    - Creates a **new commit** that records the exact inverse of the target commit.
    - Does not rewrite history; safe to use on shared/public branches.

---

### Q7: You accidentally committed sensitive credentials (API key, AWS secret) to Git. What steps do you take?
* **Answer:**
  1. **Immediate Revocation:** Invalidate/rotate the leaked secret immediately in the cloud provider/service (the secret is compromised the second it hits remote).
  2. **Remove from Git History:**
     - A simple `git rm` in a new commit still leaves the secret in historical commits.
     - Use tools like `git-filter-repo` or BFG Repo-Cleaner to completely purge the file/secret from commit history:
       ```bash
       bfg --replace-text passwords.txt my-repo.git
       ```
  3. **Force Push (Coordinated):** `git push --force-with-lease` to update remote branches.
  4. **Prevention:**
     - Add secrets to `.gitignore`.
     - Implement pre-commit hooks (e.g., `pre-commit`, `gitleaks`, `trufflehog`) and CI secret scanning to block future leaks.

---

### Q8: Explain what `git cherry-pick`, `git stash`, and `git reflog` do.
* **Answer:**
  * **`git cherry-pick <commit-hash>`:** Applies the changes introduced by a specific existing commit from another branch onto your current branch without merging the whole branch.
  * **`git stash` / `git stash pop`:** Temporarily shelves (stashes) uncommitted dirty working directory changes so you can switch branches cleanly, and restores them later.
  * **`git reflog`:** Logs every reference update (commits, checkouts, resets, rebases) made in the local repository. It is a safety net used to recover "lost" commits or recover from accidental `git reset --hard`.

---

## 3. GitOps & DevOps Best Practices

### Q9: What are Branch Protection Rules and why are they critical in CI/CD?
* **Answer:**
  - Branch protection rules enforce safeguards on critical branches (e.g., `main`, `release`):
    - Require Pull Request reviews before merging (e.g., minimum 1 senior review).
    - Require status checks to pass (CI build, unit tests, linters, SAST scans).
    - Prevent direct force pushes (`git push --force`) and branch deletion.
    - Require signed commits (GPG keys) for authenticity.

### Q10: What is `.gitignore` and why is it important in Infrastructure as Code (Terraform)?
* **Answer:**
  - `.gitignore` specifies untracked files that Git should intentionally ignore.
  - In Terraform, `.gitignore` must exclude:
    - `.terraform/` (downloaded provider binaries).
    - `terraform.tfstate` and `terraform.tfstate.backup` (contain plain-text secrets and sensitive infra metadata; state belongs in remote backend).
    - `*.tfvars` files containing production secrets/credentials.