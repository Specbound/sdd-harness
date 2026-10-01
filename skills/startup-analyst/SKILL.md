---
name: startup-analyst
description: Startup business analysis for pre-seed to Series A companies — TAM/SAM/SOM market sizing, cohort-based financial modeling with burn/runway math, SaaS/marketplace/consumer/B2B unit economics, and investor-ready business case documents. Use for market opportunity, financial projections, startup metrics, or fundraising materials.
---

# Startup Analyst

Grounds every number in a stated methodology and cited source. Conservative,
defensible assumptions beat optimistic ones — investors discount both equally
but only distrust the latter after the fact.

## Market Sizing (TAM / SAM / SOM)

| Term | Definition | Use for |
|---|---|---|
| TAM | Total revenue if 100% market share | Long-term vision, market validation |
| SAM | TAM narrowed by geography/product/capability | Realistic addressable opportunity |
| SOM | Realistic 3-5yr capture of SAM | Financial projections, fundraising |

**Three methodologies** — lead with bottom-up, always triangulate:

| Method | When | Formula |
|---|---|---|
| Bottom-up (most credible) | B2B, niche, new markets | `TAM = Σ(segment size × revenue/customer)` |
| Top-down | Established markets w/ research | `TAM = category size; SAM = TAM × geo% × segment%` |
| Value theory | New categories, disruptive innovation | `Price = value created × willingness-to-pay% (10-30%); TAM = customers × price` |

**SAM** = TAM × geographic% × product-fit% × market-readiness% (apply filters
sequentially, e.g. $10B × 40% geo × 30% segment × 60% feature-fit = $720M).

**SOM** (conservative default): Year 3 = SAM × 2-3%, Year 5 = SAM × 4-6%. New
entrants rarely exceed 5% in 5 years — justify any higher claim explicitly.

**By business model:**
- SaaS: `Total target companies × ACV × (1 + expansion rate)`
- Marketplace: `Total category GMV × take rate`
- Consumer: `Total users × ARPU × purchase frequency/yr`
- B2B services: `Target companies × avg deal size × deals/yr`

**Validate:** bottom-up vs. top-down should agree within 30%; sanity-check
against public-company revenue in the space and customer-count assumptions.
Red flags: TAM < $1B for a VC-backed pitch, SOM > 10% in 5yrs, >50% disagreement
between methodologies, conflating TAM with SAM.

## Financial Modeling

**Revenue (cohort-based):** `MRR = Σ(cohort size × retention rate × ARPU) + expansion`;
`ARR = MRR × 12`. Monthly detail for Year 1-2, quarterly Year 3, annual Year 4-5.
Typical SaaS retention curve: M1 100% → M3 90% → M6 85% → M12 75% → M24 70%.

**Cost structure targets (early-stage):**

| Category | SaaS | Marketplace | E-commerce |
|---|---|---|---|
| Gross margin | 75-85% | 60-70% | 40-60% |
| S&M % revenue | 40-60% | — | — |
| R&D % revenue | 30-40% | — | — |
| G&A % revenue | 15-25% | — | — |

Headcount ratios (early SaaS): Engineering 40-50%, S&M 25-35%, G&A 10-15%,
CS/Product 10-15%. Fully-loaded cost ≈ salary × 1.3-1.4 (benefits/taxes).

**Cash flow:** `Monthly burn = revenue − expenses` (negative = burning);
`Runway (months) = cash balance / monthly burn`. Target 12-18 months runway at
all times; buffer 6 months past the next milestone when sizing a raise.

**Three scenarios** — vary growth inputs, hold pricing/core opex/hiring roles
fixed:
- Conservative (P10): customers −30%, churn +20%, price −15%, CAC +25%
- Base (P50): primary planning scenario
- Optimistic (P90): customers +30%, churn −20%, price +15%, CAC −25%

**Fundraising:** `Post-money = pre-money + investment`; `Dilution% = investment / post-money`.
Size the raise to the next milestone + 6mo buffer, not an arbitrary round number.

**Pitfalls:** overly optimistic growth (add realism, not hope), underestimated
costs (add 20% buffer, use fully-loaded comp), ignoring cash-timing (revenue ≠
cash collected), static headcount (hiring takes 3-6mo to fill + 3-6mo to ramp),
skipping scenario analysis.

**Validation checklist:** revenue growth achievable (≤3x Yr2, ≤2x Yr3) · LTV:CAC
>3, payback <18mo · burn multiple <2.0 by Yr2-3 · revenue-per-employee rising ·
gross margin fits the model · S&M spend aligns with CAC/growth target.

## Startup Metrics & Unit Economics

**Unit economics:**
- `CAC = total S&M spend / new customers` (include salaries, tools, overhead)
- `LTV = ARPU × gross margin% / churn rate`
- `LTV:CAC` — >3.0 healthy, 1-3 needs work, <1.0 unsustainable
- `CAC payback = CAC / (ARPU × gross margin%)` — <12mo excellent, 12-18 good, >24 concerning

**Efficiency:**
- `Burn multiple = net burn / net new ARR` — <1.0 exceptional, 1-1.5 good, 1.5-2 acceptable, >2 inefficient
- `Magic number = net new ARR (qtr) / S&M spend (prior qtr)` — >0.75 scale-ready, 0.5-0.75 moderate, <0.5 don't scale
- `Rule of 40 = revenue growth% + profit margin%` — >40% excellent
- `Quick ratio = (new+expansion MRR) / (churned+contraction MRR)` — >4 healthy, <2 churn problem

**By model:**

| Model | Key metrics | Benchmark |
|---|---|---|
| SaaS | NDR, gross retention | NDR >120% best-in-class, 100-120% good; gross retention >90% excellent |
| Marketplace | GMV, take rate, fill rate | Take rate 10-25% by category; fill rate >80% = strong liquidity |
| Consumer | DAU/MAU, Day-30 retention, K-factor | DAU/MAU >50% exceptional; Day-30 >40% excellent; K>1.0 viral |
| B2B | Win rate, sales cycle, ACV, pipeline coverage | Win rate 20-30% new / 30-40% mature; pipeline 3-5x quota |

**Focus by stage:** Pre-seed → active users, retention, qualitative feedback
(revenue/CAC don't matter yet). Seed → MRR growth 15-20% MoM, set up a CAC/LTV
baseline, gross retention >85%. Series A → ARR growth 3-5x YoY, LTV:CAC >3,
NDR >100%, burn multiple <2.0, magic number >0.5.

**Avoid:** vanity metrics (total users without retention), tracking 50 metrics
instead of 5-7 core ones, ignoring unit economics pre-revenue-scale, not
segmenting by cohort/channel, chasing the dashboard instead of the business.

## Business Case Document (investor-ready)

Standard structure: Executive summary → Problem & market opportunity (incl.
TAM/SAM/SOM) → Solution & product → Competitive analysis & differentiation →
Business model & go-to-market → Financial projections (3yr summary, unit
economics, scenarios) → Team & hiring plan → Traction & milestones → Risks &
mitigation → Funding ask & use of proceeds.

**Do:** lead with the customer problem, quantify everything, cite sources,
acknowledge risks honestly, keep the executive summary to 2 pages.
**Don't:** jargon without explanation, unsupported claims, skip "why now",
ignore competition, use a generic template without company-specific detail.

## Response Approach

1. Clarify stage, business model, and the specific question before calculating
2. Gather current data via web search when needed; cite sources with dates
3. Apply the methodology above, show the formula and inputs, not just the result
4. Validate/triangulate before presenting a single number as fact
5. Present in structured sections with tables; state assumptions and limitations
6. End with specific next steps, not generic advice
