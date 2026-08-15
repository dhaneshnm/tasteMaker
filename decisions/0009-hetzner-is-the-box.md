# 0009 — Hetzner is the box

Date: 2026-08-13

> **SUPERSEDED by `decisions/0012` (GCP is the box), 2026-08-14 — one day later.**
>
> Two factual errors killed it, both findable on the day it was written:
> **CX22 is not sold in Ashburn** (Hetzner's CX line is Germany/Finland only; the
> US locations carry CPX and CCX), and the **€4.49 price was already stale** —
> Hetzner raised USA CPX pricing ~3× on **2026-06-15**, two months before this
> entry. The real Ashburn equivalent, CPX21, is **$37.49/mo**, not ~€5.
>
> The sizing analysis below — 4 GB RAM for vips, disk and traffic both
> non-constraints — was measured against this app and **survives intact**; 0012
> carries it forward unchanged. Only the vendor and the price collapsed.
>
> Left standing rather than rewritten: this is the record of what was decided and
> on what evidence, including the part that was wrong.

Position: Tondo runs on one Hetzner Cloud CX22 in Ashburn, Ubuntu 24.04, deployed
by Kamal 2 exactly as `config/deploy.yml` already describes. No managed platform,
no hyperscaler, no second environment. Direction-level because it is where the
product lives and it is the last thing standing between a finished baseline and a
URL somebody outside this repo can open.

## What was actually being decided

`config/deploy.yml` has been written, commented and rehearsed locally since the
shell landed, and it still carries a TEST-NET address. The stack was never the
open question — CLAUDE.md fixed Kamal 2 on a single VPS. The open question was
whose VPS, and it had been left open long enough that it was quietly the reason
nothing was deployed.

## What decided it

Measured against this app, not against a generic Rails app.

- **The blobs are small.** 122 stored images: 51.8 MB total, mean 435 KB, median
  409 KB, max 1 MB. Two sizes are ever served — the full plate and a 240px
  variant. Two thousand images projects to roughly **1 GB**, against CX22's 40 GB
  local SSD. Disk is not a constraint at this scale or ten times it.
- **Traffic is not a constraint either.** 100 daily readers at a generous 1 MB a
  session is ~6 GB over two months. CX22 includes 20 TB. Metered egress — the one
  line item that could have made an image-heavy product expensive — is priced at
  zero here, and no forecast within two orders of magnitude reaches the cap.
- **RAM is the only real constraint**, and it is vips generating variants, not
  Puma serving them. That is what rules out the 1 GB tier, and it is the whole
  argument for 4 GB.
- **Cost, all in:** CX22 (~€5) + IPv4 (€0.60) + automated snapshots (+20%) ≈
  **€7/mo**, about €14 for the two months to and past the kill review. Confirm the
  US-location price at purchase; EU list is €4.49 and US runs slightly above.

## What was rejected, and why

- **AWS and GCP.** Kamal needs one thing: an Ubuntu box with root SSH, a public
  IP and a disk. Both vendors sell that only through VPC, security groups, IAM and
  EBS lifecycle. Roughly 3× the price for a smaller machine, plus metered egress,
  plus hours of setup charged against a bet that is reviewed on **Aug 31**. Their
  actual product — managed services and elastic scale — is the thing this bet has
  no use for.
- **Railway.** The strongest rejected option, and it was rejected on a close call.
  It wins the two things that hurt today: no account-verification risk on a
  deadline, and volume backups that cover a SQLite file natively — most of session
  gate 6 for free. It loses on price (~2× for a fraction of the machine), on
  metered egress, on a 5 GB Hobby volume that the artwork cache grows into, and on
  making `deploy.yml` dead config. Lock-in would have been low — same Dockerfile —
  so this stays a live fallback rather than a closed door.
- **DigitalOcean.** Same shape as Hetzner, ~2× the price for half the machine.
  Kept as the **same-hour fallback** if Hetzner account verification stalls: the
  €5/mo difference is worth nothing next to losing the launch day to an ID check.
- **A staging environment, a second server, a managed Postgres.** Infrastructure
  for later. The install floor is 50; SQLite on a local disk cannot be
  load-balanced anyway.

## What this decision does not solve

Hetzner's automated backups are VM snapshots, and a snapshot of a live SQLite
file can capture a torn WAL. That is not a restorable backup and it does not
close session gate 6, which wants `sqlite3 .backup` to an offsite target plus one
restore actually performed and logged. Choosing the host did not make that work
smaller — it is unchanged and still owed before the first external reader.

## Prediction (falsifiable, time-bound)

Through the **Aug 31, 2026** kill review: total hosting spend stays under **€20**,
the app runs on one CX22 the whole time, and no capacity limit — disk, RAM,
traffic — forces a resize or a migration.

Falsified if the product moves to a second host or a managed platform, if a
second server or accessory container is added, if the box is resized for load, or
if any hosting limit is the stated reason something shipped late.

## Enforcement

`config/deploy.yml` is the enforcement: it is the only deploy path in the repo,
it names one server, and it carries no accessories. A second host config, a
platform manifest, or an `accessories:` block appearing in this repo is the
falsification showing up in the diff.

The two remaining `CHANGEME` values in that file — `servers.web[0]` and
`proxy.host` — are the receipt this decision is still unpaid. It is not done when
the file is edited; it is done when `kamal deploy` has run and the domain answers
over HTTPS.
