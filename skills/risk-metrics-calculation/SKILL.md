---
name: risk-metrics-calculation
description: Use when computing or reviewing portfolio risk numbers — VaR, CVaR, Sharpe, Sortino, drawdown, beta — or setting position limits from them.
risk: unknown
source: community
---

# Risk Metrics

## Use this skill when

- A risk number has to be produced, reviewed, or defended to someone who will act on it
- Position sizes or stop-outs are being derived from one of these numbers
- A risk dashboard or a regulatory report needs the arithmetic to be right
- A metric looks wrong and the convention, not the data, is the suspect

## Pin the conventions before writing any code

Most wrong risk numbers are convention errors, not math errors. Decide and write down:

1. **Simple or log returns.** Simple returns aggregate across positions in one period; log
   returns aggregate across time for one position. Mixing them silently biases anything
   compounded.
2. **Sign.** Report VaR and CVaR as positive loss magnitudes. Half of all VaR bugs are a
   flipped sign on the lower tail quantile.
3. **Periodicity and the annualization factor.** 252 trading days, 52 weeks, 12 months.
   One factor, applied in one place.
4. **Sample or population standard deviation.** At n=1000 the gap is ~0.05% and does not
   matter; at n=30 it does. Pick ddof and keep it.
5. **Risk-free rate conversion.** Compound it: `(1+rf)**(1/252)-1`, not `rf/252`. For
   rf=2% that is 0.00007858 against 0.00007937 — small, but it is free to get right.

## The metrics and the bug each one attracts

| Metric | Definition | The bug |
|---|---|---|
| Historical VaR(α) | `-quantile(returns, 1-α)` | off-by-one on the index; floor the index, do not round |
| Parametric VaR(α) | `-(μ - z_α·σ)` | assumes normality — see the numbers below |
| CVaR / Expected Shortfall | mean of returns **at or beyond** the VaR quantile | returning the quantile itself instead of the tail mean |
| Volatility | stdev × √periods | annualizing an already-annualized input twice |
| Sharpe | `mean(excess)/stdev(excess) × √252` | subtracting rf from the numerator only |
| Sortino | `mean(r-MAR)/downside_dev × √252` | the denominator convention — see below |
| Max drawdown | min of `wealth/running_peak - 1` | computing it off the return series instead of the wealth curve |
| Calmar | CAGR / abs(maxDD) | CAGR from a mean return rather than from end-over-start wealth |
| Beta | `cov(r_p, r_m)/var(r_m)` | using correlation, which drops the volatility ratio |

## Numbers from a checked run

Computed on 1,000 synthetic daily returns drawn from a fat-tailed mixture (5% shock regime,
σ=4.5%; 95% calm regime, σ=0.9%). The point is the size of each gap, not the exact values.

- **Parametric VaR fails in both directions, not one.** Normal VaR95 = 0.02368 against a
  historical 0.01802 — it *overstates* the moderate tail by 31%. Normal VaR99 = 0.03363
  against a historical 0.04818 — it *understates* the far tail by 30%. "Normal VaR is
  conservative" is not a safe thing to assume.
- **CVaR95 = 0.03527 against VaR95 = 0.01802.** The expected loss given a breach is nearly
  double the breach threshold. CVaR ≥ VaR always; if your output violates that, the tail
  mean is being taken over the wrong slice.
- **The Sortino denominator convention moves the answer 47%.** Dividing the squared
  downside deviations by N gives 0.010236 and a Sortino of 0.5396; dividing by the count of
  downside periods only gives 0.014994 and 0.3683. Both are in published use. State which
  one you used, or the ratio is not comparable to anyone else's.
- **Max drawdown was -42.4% while the worst single day was -10.1%.** Drawdown is a
  path property. A return-series minimum is a different statistic wearing its name.

## Limits to state whenever you hand one of these over

- **VaR is not subadditive**, so it is not a coherent risk measure and portfolio VaR can
  exceed the sum of its parts. Checked: two positions each with VaR99 = 0, combined
  VaR99 = 1.0. Two independent 1%-loss-probability exposures each sit inside the 99%
  threshold alone and together do not. Use CVaR where you need sub-additivity to hold.
- **√time scaling assumes returns are independent and identically distributed.** With
  autocorrelation or volatility clustering it understates multi-period risk. Quote the
  10-day number as "1-day VaR × √10" so the assumption travels with it.
- **Every historical metric is conditioned on its window.** A VaR fitted on a calm sample
  cannot see a regime it never contained. Report the window length and the dates.
- **Sharpe annualized by √252 inherits the same iid assumption** and is not comparable
  across strategies with different holding periods.

## Resources

- `resources/implementation-playbook.md` — longer worked examples and code samples.
  Treat its library versions and any model or vendor names in it as illustrative; the
  conventions table above is the part to follow.
