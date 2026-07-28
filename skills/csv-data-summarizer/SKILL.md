---
name: csv-data-summarizer
description: Analyze a CSV end-to-end without asking questions — pandas stats, missing-data audit, and only the charts the data supports. Use when the user shares or references a CSV wanting a summary, analysis, or insights.
metadata:
  dependencies: python>=3.8, pandas, matplotlib, seaborn
---

# CSV Data Summarizer

When the user provides a CSV, run the full analysis immediately and present complete results in one response. Do not ask what they want, list options, or offer choices.

## Procedure

1. **Load and inspect** with pandas: shape, dtypes, date-like columns (name contains "date"/"time", or parseable as datetime), numeric columns, categorical columns.
2. **Report the basics**: dataset overview (rows × columns, column types), summary statistics for numeric columns, missing-data audit (% per column).
3. **Pick analyses the data actually supports** — never force a chart the columns can't back:
   - Time-series trends only when a date/timestamp column exists
   - Correlation heatmap only with ≥2 numeric columns
   - Frequency counts / cross-tabs for categorical columns
   - Domain-relevant framing when columns imply one (revenue → sales trends, ratings → response distributions, patient IDs → demographic/temporal patterns)
4. **Close with 2–4 insights** grounded in this dataset's patterns, not generic advice.

## Bundled script

`analyze.py` in this skill directory implements steps 1–3 (`summarize_csv(file_path)`, saves charts as PNGs):

```bash
python ~/.claude/skills/csv-data-summarizer/analyze.py <file.csv>
```

Use it when pandas/matplotlib/seaborn are installed (`requirements.txt` pins the minimums); otherwise write the equivalent inline. Fixtures: `resources/sample.csv` (21 rows, sales) and `examples/showcase_financial_pl_data.csv` (45 rows, P&L).

Script-level limits worth knowing: PNGs land in the **current working directory** under fixed names (`correlation_heatmap.png`, `time_series_analysis.png`, `distributions.png`, `categorical_distributions.png`); date detection is name-based only (`date`/`time` in the column name), so parse date-like columns yourself when the name doesn't say so; columns containing `id` are skipped in categorical analysis.

## Constraints

- Handle missing values without failing — report them, don't silently drop.
- Include all numeric columns in the statistical summary.
