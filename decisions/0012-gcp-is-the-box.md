# 0012 — GCP is the box

Date: 2026-08-14

**Supersedes `decisions/0009` (Hetzner is the box).**

Position: Tondo runs on one GCP Compute Engine **e2-medium** in **us-central1**,
Ubuntu 24.04, on a **personal** billing account, deployed by Kamal 2 exactly as
`config/deploy.yml` already describes. No managed platform, no second
environment, no accessory containers. Direction-level because it reverses a
decision committed one day ago and because it is still the last thing standing
between a finished baseline and a URL somebody outside this repo can open.

## What was actually being decided

Not "which host is best." `decisions/0009` chose a box that **cannot be bought**,
and the reopening was forced by facts rather than by preference or taste.

Two errors, one of them mine and one of them stale research:

1. **CX22 does not exist in Ashburn.** Hetzner's CX line is Germany/Finland only.
   The US locations — Ashburn and Hillsboro — carry CPX and CCX exclusively.
   0009 specified a machine type in a location that has never sold it.
2. **The €4.49 price was already wrong when 0009 was written.** Hetzner adjusted
   cloud pricing on **2026-06-15**, raising USA CPX instances by roughly 3×. That
   change predates 0009 by two months. The decision did not fail to anticipate a
   later event; it failed to check a current one.

0009 also instructed "confirm the US-location price at purchase." That check ran
today and is what surfaced both errors — the trigger worked, one day late.

## What survives from 0009, unchanged

The sizing analysis was measured against this app and none of it collapsed with
the vendor:

- **4 GB RAM is the real constraint**, and it is vips generating variants rather
  than Puma serving them. That still rules out every 1–2 GB tier and it is still
  the whole argument for 4 GB.
- **Disk is not a constraint.** Measured today: `storage/` is **974 MB**. With
  OS, Docker layers and Kamal's retained prior versions, ~8 GB is used of 20.
- **Traffic is not a constraint.** ~3 GB/month against any plausible allowance.

Only the vendor and the price collapsed. The requirements did not move.

## What decided it

Real prices, checked today, for the only three options that clear 4 GB in a US
location. Seventeen days remain to the **Aug 31** kill review, so the honest
denominator is the life of the bet, not a month:

| Host | Spec | $/mo | **17 days** |
|---|---|---|---|
| DigitalOcean Basic | 2 vCPU / 4 GB / 80 GB | 24.00 | $13.16 |
| **GCP e2-medium** | 2 vCPU / 4 GB / 20 GB | **30.47** | **$16.71** |
| Hetzner CPX21 (Ashburn) | 3 vCPU / 4 GB / 80 GB | 38.14 | $20.92 |

GCP line items, us-central1: e2-medium **$24.46** + 20 GB pd-balanced **$2.00** +
external IPv4 **$3.65** ($0.005/hr) + egress ~3 GB **$0.36** = **$30.47/mo**.
E2 is excluded from sustained-use discounts, so $24.46 is flat, not a list price
with a discount waiting behind it.

**The entire spread across all three options, for the whole remaining life of
this bet, is $7.76. GCP costs $3.55 more than the cheapest.**

`decisions/0009` rejected GCP on **setup hours**, not on price — VPC, firewall
rules, IAM, billing, "hours of setup charged against a bet reviewed on Aug 31."
That argument is now void, and it was void on evidence rather than on assertion:
the user is fluent on the platform and pays for existing projects on it, and
**gcloud SDK 557.0.0 is installed and authenticated on the build machine with
`us-central1-a` already set as the default zone.** The hours 0009 was pricing
are not there to spend.

So the decision is made **on speed, not on price.** DigitalOcean is $3.55
cheaper and costs a new account, a new billing relationship and a new key upload
— 20–40 minutes on a day that has already missed `BET.md`'s live-by date. $3.55
does not buy that time back.

## What was rejected, and why

- **DigitalOcean, $24/mo.** The cheapest option and the closest call. 0009 had
  already named it the same-hour fallback, so it was pre-authorized. It loses on
  the only currency that is actually scarce today: minutes. Stays the live
  fallback if a GCP billing or org problem stalls the box.
- **Hetzner CPX21 Ashburn, $38.14/mo.** Keeps 0009's vendor and location intact
  and is the most expensive of the three. Buys one extra vCPU there is no
  evidence this app needs.
- **Hetzner CAX21 EU, €10.49/mo.** Cheapest by a wide margin and the most machine
  of anything considered — 4 vCPU ARM, 8 GB, 80 GB — and arm64 would build
  natively on this Mac. Rejected on ~90ms extra RTT to US readers on every
  request, against the Better-bucket quality bar that says *fast: no stutter,
  instant open*. Paying for a slower product to save €20 is the wrong trade for
  a bet whose only moat claims are voice and habit.
- **1-year committed-use discount, −37% → $15.41/mo.** Cheapest of everything.
  Requires a **twelve-month commitment on a bet that is reviewed in seventeen
  days**. Textbook infrastructure for later, and `CLAUDE.md` names that as the
  user's own historical failure pattern.
- **Spot VMs, −60%+.** GCP reclaims them on 30 seconds' notice. Not for the only
  production box.
- **GCP Always Free tier.** `e2-micro` is 1 GB RAM and fails the vips constraint
  outright. The 30 GB pd-standard and 1 GB egress allowances are per *billing
  account* and are almost certainly already absorbed by existing projects.
  Modeled at zero.
- **A staging environment, a second server, managed Postgres, Cloud SQL, GCS for
  blobs.** Unchanged from 0009 and still infrastructure for later. The install
  floor is 50 and SQLite on a local disk cannot be load-balanced anyway.

## The GCP-specific detail that would otherwise be rediscovered

Kamal defaults to `ssh.user: root`. GCP's Ubuntu images use OS Login and
provision keys to a named sudo user, so a default Kamal deploy fails to
authenticate. The fix keeps `deploy.yml`'s ssh block at its defaults — set at
instance-creation time, not afterward:

```
--metadata=enable-oslogin=FALSE,ssh-keys="root:$(cat ~/.ssh/id_ed25519.pub)"
```

Ubuntu ships `PermitRootLogin prohibit-password`, so a root **key** is accepted
while a root password still is not. Two further GCP defaults bite here: the
default VPC allows tcp:22 but **not 80 or 443**, which need explicit firewall
rules, and an **ephemeral external IP changes on stop/start**, which would
silently break both DNS and the certificate. The address is reserved static and
attached at creation.

## What this decision does not solve

- **Backups. Unchanged from 0009 and still owed.** GCP persistent-disk snapshots
  are cheap and easy to schedule — and a snapshot of a live SQLite file can still
  capture a torn WAL. That is not a restorable backup. Session gate 6 wants
  `sqlite3 .backup` to an offsite target plus one restore actually performed and
  logged, and choosing a third host in two days has not made that work smaller.
- **Metered egress from byte one.** DigitalOcean bundles 4 TB and Hetzner 2 TB;
  GCP meters every gigabyte. At ~3 GB/month this is cents. It is a **tail-risk
  shape, not a cost** — the downside is uncapped if the app is scraped or spikes,
  and there is no billing alarm configured. Naming it so it is not discovered on
  an invoice.
- **The corporate-org hazard.** The gcloud account configured on this machine is
  `dhanesh.neelamana@master-ed.com`, project `master-ed-storage`, inside an org
  already enforcing tag policies. **Tondo does not go there.** A personal App
  Store product living in a company org means company billing, company org
  policy, and a real ownership question. This decision specifies a personal
  billing account and is falsified if the instance lands in the master-ed org.
- **Everything that actually gates the bet.** Zero of `BET.md`'s five thresholds
  move when this box boots.

## Prediction (falsifiable, time-bound)

Through the **Aug 31, 2026** kill review: total GCP spend on this project stays
under **$25**, the app runs on one e2-medium the whole time, and no capacity
limit — disk, RAM, egress — forces a resize or a migration.

Falsified if the product moves to a fourth host or a managed platform, if a
second instance or accessory container is added, if the machine type is changed
for load, if the instance is created inside the master-ed org, or if any hosting
limit is the stated reason something shipped late.

## Enforcement

`config/deploy.yml` remains the enforcement: it is the only deploy path in the
repo, it names one server, and it carries no accessories. A second host config, a
platform manifest, or an `accessories:` block appearing in this repo is the
falsification showing up in the diff.

The two remaining `CHANGEME` values in that file — `servers.web[0]` and
`proxy.host` — plus `TONDO_URL` in `ios/Config/Release.xcconfig` are the receipt
this decision is still unpaid. **Three hosts have now been chosen and zero have
been deployed to.** It is not done when the file is edited; it is done when
`kamal deploy` has run and **dailytondo.com** answers over HTTPS.

## The adversarial note (R7)

This is the second host decision in two days and the third named box. Today is
**Aug 14** — `BET.md`'s "app live on App Store" date, which is now missed, not at
risk. The scoreboard is unchanged: not live, 0 of 4 posts, 0 of 3 keywords, 0 of
5 user conversations, 0 of 50 installs.

The $7.76 that separated the best and worst options has now consumed more
attention than it can possibly repay. Writing this entry is the last host work
that gets done before a box exists.
