---
name: cro
description: Diagnose and raise conversion rate across pages, forms, popups, signup flows, onboarding, and in-app paywalls/upgrade screens. Use when asked to improve conversion, cut form/signup friction, fix a weak landing or pricing page, design activation/onboarding, or tune upgrade prompts.
---

# Conversion Rate Improvement (CRO)

Evidence-based diagnosis before tactics. Never recommend blind A/B testing or copy
tweaks without first identifying the structural constraint.

## Universal Approach

1. **Score readiness before testing.** For any surface, rate 0-100 across weighted
   categories (value clarity, goal focus, trust, friction, objection handling).
   Below ~70 = fix fundamentals first; testing noise will swamp the signal.
2. **One job per surface.** One primary goal, one primary CTA. Secondary actions
   are visually demoted, never competing.
3. **Value before ask.** Show/prove value before requesting signup, payment, or
   a form field. Order: value → commitment, never the reverse.
4. **Every field/step/interruption has a cost.** Each one must earn its place —
   if the data isn't used downstream, it's friction, not value.
5. **Respect the no.** Easy dismissal, no dark patterns, no guilt copy. Trust
   compounds into future conversion; coercion burns it.
6. **Timing beats design.** A well-designed prompt at the wrong moment fails.
   Trigger on behavior/engagement signals, not arbitrary timers.

**Standard output format** for any audit: Issue → Impact → Fix → Priority, then
group into Quick Wins (no test needed) / High-Impact (needs design+test) / Test
Hypotheses (hypothesis, change, expected behavior, primary metric).

**Don't test when:** traffic is too low to reach significance, the surface scores
below the readiness threshold, or more than one variable would change at once.

---

## Page CRO (homepage, landing, pricing, feature pages)

**Diagnose in impact order:**
1. Value prop & headline — problem, audience, differentiation, outcome, clear in ≤5s
2. CTA hierarchy — one primary action, appropriate commitment level, repeated at decision points
3. Visual hierarchy — reading path, whitespace, supportive (not decorative) visuals
4. Trust/social proof — specific (numbers > adjectives), placed near CTAs
5. Objection handling — price/fit/time-to-value/risk, resolved via FAQ/guarantee/comparison
6. Friction — load speed, mobile, excess fields, unclear next step

**By page type:** Homepage = positioning + audience routing. Landing = message
match to traffic source + single CTA. Pricing = clarity + risk reduction. Feature
pages = benefit framing + proof. Blog = contextual CTAs, not hard sells.

**Traffic-message match matters**: headline/hero must match the ad, email, or
search intent that brought the visitor — no bait-and-switch.

Route the bottleneck: drop-off *after* the page → signup flow; the form itself →
form section below; considering an overlay → popup section below.

---

## Form CRO (lead capture, contact, demo, application, checkout — non-signup)

**Field cost rule of thumb:** 3 fields = baseline; 4-6 fields ≈ −10-25% completion;
7+ fields ≈ −25-50%+. Every required field must be justified — not "nice to have,"
not inferable, not unused downstream.

| Field | Guidance |
|---|---|
| Email | Single field, no confirmation, inline typo correction |
| Name | One "Name" field by default; split only if operationally required |
| Phone | Optional unless critical; explain why if required; auto-format |
| Company | Auto-suggest / infer from email domain; enrich post-submit instead |
| Free text | Optional unless essential; give length/purpose guidance |
| Selects | Radio if <5 options; searchable select if long list |

**Layout:** single column default; easiest fields first, sensitive/high-effort
last. Labels always visible (never label-as-placeholder). Multi-step when 6+
fields or distinct logical sections — show progress, allow back nav, save state.

**Errors:** validate after field interaction (not keystroke), specific/human/
actionable messages ("Please enter a valid email" not "Invalid input"), never
clear user input on error.

**Submit copy:** action + outcome ("Get My Quote", "Request Demo"), never
"Submit"/"Send". Disable + show loading state on click.

**Mobile (mandatory):** ≥44px touch targets, correct keyboard types, autofill,
single column.

---

## Popup CRO (modals, overlays, slide-ins, banners)

**One popup, one job.** Value must register in <3 seconds or it fails.

| Trigger | Use for |
|---|---|
| Click-triggered (highest intent) | Lead magnets, demos, gated assets |
| Scroll-based (25-50% depth) | Blog/long content engagement |
| Exit intent (cursor→chrome / mobile back) | E-commerce, lead recovery |
| Time-based (30-60s active, not 5s) | Broad list building — use sparingly |
| Behavior-based | Pricing-page visits, cart abandonment, repeat views |

**Design rules:** visible close "X", click-outside and ESC both close, large
mobile tap target; prefer bottom slide-ups over full-screen blockers on mobile.
Frequency-cap to once/session with a 7-30 day cooldown; exclude checkout, signup,
and other critical-conversion-step pages entirely.

**Compliance:** keyboard-navigable, focus-trapped, no pre-checked opt-ins;
avoid intrusive full-screen mobile interstitials (Google penalizes these).

**Directional benchmarks:** email capture 2-5%, exit intent 3-10%, click-triggered 10%+.

---

## Signup Flow CRO (account creation, trial activation)

**Minimize fields.** Essential: email (or phone) + password. Often needed: name.
Usually deferrable: company, role, team size, phone — collect via progressive
profiling post-signup instead.

**Password UX:** show/hide toggle, requirements shown upfront (not after
failure), allow paste, prefer a strength meter over rigid rules.

**Social auth:** place prominently — often converts better than email. B2C:
Google/Apple/Facebook. B2B: Google/Microsoft/SSO.

**Single-step** when ≤3 fields, simple B2C, high-intent traffic. **Multi-step**
when >3-4 fields or segmentation needed — progressive commitment pattern: email
only → password+name → optional customization, each step completable in seconds.

**Patterns by model:** B2B SaaS trial = email+password → name+company (optional
role) → onboarding. B2C app = social/email auth → straight into product. E-commerce
= guest checkout by default, account creation deferred to post-purchase.

Verification: consider delaying email verification until it's actually needed;
magic links as a passwordless alternative.

---

## Onboarding CRO (activation, first-run, time-to-value)

**Define activation first:** find the action that most correlates with
retention — the "aha moment" (e.g., PM tool: create project + add teammate;
analytics: install tracking + see first report; marketplace: first transaction).

**Time-to-value is everything** — remove every step between signup and that
moment; consider letting users experience value *before* signup.

**One goal per first session.** Interactive > tutorial; do the real task, don't
narrate it.

**Checklist pattern** (when multiple setup steps exist): 3-7 items, ordered by
value with quick wins first, visible progress, dismissable — never trap users.
Empty states are onboarding moments: explain the area, show it populated, give
one primary "add first item" CTA.

**Multi-channel:** welcome email immediate; incomplete-onboarding nudges at
24h/72h; in-app messaging should reinforce, not duplicate, email.

**Stalled users:** define inactivity/incomplete-setup criteria, re-engage via
email sequence (address blockers, offer help) or in-app "pick up where you left
off"; human outreach for high-value accounts.

**Track:** activation rate, time-to-activation, step-level funnel drop-off,
Day 1/7/30 retention.

---

## Paywall / Upgrade CRO (feature gates, limits, trial expiration, tier upsell)

**Show the upgrade only after value has been experienced** — never during
onboarding, never mid-flow, never repeatedly after dismissal.

| Trigger | Approach |
|---|---|
| Feature gate (clicked paid feature) | Explain why it's paid, preview it, quick unlock path, allow "continue without" |
| Usage limit hit | Show what was reached + what upgrading unlocks; don't block abruptly |
| Trial expiring | Warn at 7/3/1 days; summarize value received; easy reactivation post-expiry |
| Soft/time-based prompt | Non-blocking banner, highlight unused paid features, easy dismiss |

**Screen components:** benefit-led headline ("Unlock X to get Y", not "Upgrade
for $X/mo") → value demonstration (preview/before-after) → pricing (clear,
monthly/annual) → specific CTA ("Upgrade to Pro") → explicit escape hatch
("Continue with Free").

**Anti-patterns (never do):** hidden close button, buried downgrade option,
misleading urgency/countdown, guilt-trip copy, surprise charges, hard-to-cancel
flow — these are dark patterns and destroy trust even when they lift short-term
conversion.

**Mobile:** follow platform conventions (iOS/Android paywall styling), show
subscription terms and a "restore purchases" option for store compliance.

---

## Measurement Checklist (any surface)

Track: impression/start rate → completion/conversion rate → step/field-level
drop-off → error rate → time-to-complete → device split. Compare against the
readiness score, not against the raw conversion number alone — a 2% lift on a
sub-70 page is noise.
