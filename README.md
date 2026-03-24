# Pokémon TCG Data – Controlled Fork

This repository is a **controlled fork** of the upstream Pokémon TCG data repository.

Its purpose is to:

* Track upstream data precisely
* Retain fork-owned documentation and tooling
* Provide **predictable, auditable updates** for downstream consumers (devices, services, CI)

---

## Fork invariants (very important)

After **every** upstream sync, the repository must satisfy:

```
main = upstream/<commit>
     + README.md        (fork-owned)
     + sync_upstream.sh    (fork-owned)
```

Everything except these two files must match upstream **exactly**.

---

## Branch model

| Branch    | Purpose                            |
| --------- | ---------------------------------- |
| `main`    | Upstream mirror + fork-owned files |
| `release` | Stable branch consumed by devices  |

**Devices MUST track `release`, never `main`.**

---

## Remotes

* `origin` → this fork (authoritative distribution point)
* `upstream` → original Pokémon TCG data repository

Verify:

```bash
git remote -v
```

---

## Fork-owned files

The following files are **owned by the fork** and are preserved automatically during syncs:

* `README.md`
* `sync_upstream.sh`

They must never be edited as part of a normal upstream update.

---

## `sync_upstream` (authoritative update mechanism)

All upstream updates **must** be performed using the `sync_upstream` script.

Manual `git merge`, `git pull`, or ad-hoc resets are forbidden.

### Supported modes

```bash
./sync_upstream.sh latest
./sync_upstream.sh <UPSTREAM_COMMIT_SHA>
./sync_upstream.sh latest --tag <TAG_NAME>
./sync_upstream.sh <UPSTREAM_COMMIT_SHA> --tag <TAG_NAME>
```

### What the script does

1. Fetches upstream
2. Resolves target commit (`latest` or explicit SHA)
3. Preserves fork-owned files
4. Hard-resets `main` to the upstream commit
5. Restores fork-owned files
6. Commits fork-owned files if needed
7. Force-pushes `main` safely (`--force-with-lease`)
8. Creates an **annotated release tag**

---

## Auto-tagging policy

After every successful sync, the script creates an **annotated tag**:

```
rYYYY-MM-DD
```

Example:

```bash
r2026-02-01
```

### Tag rules

* Tags are **immutable**
* Tags are never moved or deleted
* One tag per day per sync
* If a tag already exists for the day:

  * It must already point to `HEAD`
  * Otherwise the script aborts

Tags provide:

* Auditability
* Explicit rollback points
* CI / manifest integration later

Devices do **not** track tags — they track `release` only.

---

## Typical operational flow

1. Sync upstream into `main`

   ```bash
   ./sync_upstream.sh latest
   ```

2. Validate locally (optional)

3. Promote to `release`

   ```bash
   git checkout release
   git merge --ff-only origin/main
   git push origin release
   ```

4. Devices update automatically

---

## Rollback procedure (devices)

Rollback `release` to a known-good tag or commit:

```bash
git checkout release
git reset --hard rYYYY-MM-DD
git push origin release --force-with-lease
```

Devices will roll back cleanly on their next update cycle.

---

## Enforcement rules

* `main` **may be force-pushed** (by design)
* `release` is **never rewritten** except during explicit rollbacks
* All upstream updates go through `sync_upstream`
* Fork-owned files are never modified manually during syncs

---

## Rationale

This model provides:

* Zero-merge-conflict upstream tracking
* Explicit, auditable divergence
* Deterministic device updates
* Instant rollbacks
* CI-friendly history

This README defines the **authoritative workflow** for this fork.

All automation and tooling must follow it.
