# FTMO 4-Year Every-Tick Backtest Performance Summary
## SprintPA Q8 No Thursday (`SprintPA_Q8_NoThu`)

* **Broker / Environment:** FTMO-Demo (`FTMO Global Markets MT5 Terminal`)
* **Symbol / Timeframe:** `XAUUSD` (Gold) / `M3`
* **Test Model:** Model 0 (Every tick based on real ticks from FTMO feed)
* **Testing Period:** 2022.11.01 – 2026.10.31 (4 Years Full / 48 Months)
* **Initial Capital:** $10,000.00 | Leverage: 1:100
* **Risk Model:** Fixed Risk per Trade = 0.75% of Balance (Safe FTMO 2-Step Mode)
* **Daily Loss Guard:** 4.0% Lock (Hard protection below FTMO 5.0% threshold)
* **Deal Matching Audit:** Final balance in Strategy Tester = Sum of CSV deals ($12,642.02, OK)

---

### 1. Overall 4-Year Performance Metrics

| Metric | SprintPA Q8 No Thursday (Champion) | SprintPA Q8 Standard | SprintPA Q7 D3 (Base) |
|---|---|---|---|
| **Net Profit** | **+$2,642.02 (+26.42%)** | +$1,184.10 (+11.84%) | +$406.47 (+4.06%) |
| **Total Closed Trades** | **353** | 467 | 501 |
| **Win Rate** | **50.7%** (179W / 174L) | 48.4% (226W / 241L) | 47.7% (239W / 262L) |
| **Profit Factor** | **1.20** | 1.07 | 1.02 |
| **Peak-to-Trough Drawdown** | **9.79%** (Passed <10.0%) | 9.93% (Passed <10.0%) | 11.73% (Failed >10.0%) |
| **Max Capital Dip Below $10k** | **7.26%** (Lowest $9,274.00) | 6.55% | 9.88% |
| **Worst Single Day Loss** | **-1.88%** (Far below 5.0% daily limit) | -2.11% | -2.33% |
| **Negative Months Count** | **18 / 48 Months** (37.5%) | 22 / 48 Months | 24 / 48 Months |
| **Average Annual Return** | **+6.61% / Year** | +2.96% / Year | +1.02% / Year |
| **Average Monthly Return** | **+0.55% / Month** | +0.25% / Month | +0.08% / Month |
| **FTMO 2-Step Phase 1 Pass Rate** | **92.9% Passed** (0.0% Failed) | 77.5% Passed (0.0% Failed) | 71.0% Passed (1.3% Failed) |

---

### 2. Yearly Breakdown (Nov to Oct Annual Cycles)

| Cycle Period | Net Profit ($) | Return (%) | Trades | Win Rate | Profit Factor | Peak DD (%) | Worst Day Loss |
|---|---|---|---|---|---|---|---|
| **2022 - 2023** | -$259.96 | **-2.60%** | 84 | 47.6% | 0.92 | 9.80% | -0.86% |
| **2023 - 2024** | +$557.00 | **+5.70%** | 69 | 53.6% | 1.24 | 4.70% | -1.44% |
| **2024 - 2025** | +$364.73 | **+3.50%** | 90 | 50.0% | 1.11 | 7.10% | -1.45% |
| **2025 - 2026** | +$1,980.25 | **+18.60%** | 110 | 51.8% | 1.44 | 3.40% | -1.88% |
| **Total 4 Years** | **+$2,642.02** | **+26.42%** | **353** | **50.7%** | **1.20** | **9.79%** | **-1.88%** |

---

### 3. Monthly Breakdown (All 48 Months)

| Month | Net PnL ($) | Return (%) | Trades | Win / Loss | Win Rate |
|---|---|---|---|---|---|
| `2022-11` | +$70.06 | +0.70% | 7 | 4W / 3L | 57.1% |
| `2022-12` | -$231.06 | -2.31% | 9 | 3W / 6L | 33.3% |
| `2023-01` | -$5.00 | -0.05% | 12 | 6W / 6L | 50.0% |
| `2023-02` | -$70.16 | -0.70% | 1 | 0W / 1L | 0.0% |
| `2023-03` | +$104.90 | +1.05% | 9 | 5W / 4L | 55.6% |
| `2023-04` | +$134.90 | +1.35% | 6 | 4W / 2L | 66.7% |
| `2023-05` | -$360.78 | -3.61% | 9 | 2W / 7L | 22.2% |
| `2023-06` | -$289.04 | -2.89% | 6 | 1W / 5L | 16.7% |
| `2023-07` | -$45.02 | -0.45% | 6 | 3W / 3L | 50.0% |
| `2023-08` | +$115.10 | +1.15% | 6 | 4W / 2L | 66.7% |
| `2023-09` | +$130.08 | +1.30% | 6 | 4W / 2L | 66.7% |
| `2023-10` | +$194.10 | +1.94% | 7 | 4W / 3L | 57.1% |
| `2023-11` | +$201.06 | +2.01% | 7 | 5W / 2L | 71.4% |
| `2023-12` | -$145.04 | -1.45% | 4 | 1W / 3L | 25.0% |
| `2024-01` | +$139.92 | +1.40% | 4 | 3W / 1L | 75.0% |
| `2024-02` | +$159.00 | +1.59% | 4 | 3W / 1L | 75.0% |
| `2024-03` | -$83.08 | -0.83% | 5 | 2W / 3L | 40.0% |
| `2024-04` | +$176.96 | +1.77% | 2 | 2W / 0L | 100.0% |
| `2024-05` | +$187.08 | +1.87% | 11 | 6W / 5L | 54.5% |
| `2024-06` | +$52.02 | +0.52% | 5 | 3W / 2L | 60.0% |
| `2024-07` | +$104.94 | +1.05% | 7 | 4W / 3L | 57.1% |
| `2024-08` | -$78.96 | -0.79% | 7 | 3W / 4L | 42.9% |
| `2024-09` | +$5.02 | +0.05% | 7 | 3W / 4L | 42.9% |
| `2024-10` | -$152.00 | -1.52% | 6 | 2W / 4L | 33.3% |
| `2024-11` | +$336.88 | +3.37% | 10 | 7W / 3L | 70.0% |
| `2024-12` | -$585.12 | -5.85% | 10 | 1W / 9L | 10.0% |
| `2025-01` | +$252.04 | +2.52% | 7 | 5W / 2L | 71.4% |
| `2025-02` | +$101.06 | +1.01% | 5 | 3W / 2L | 60.0% |
| `2025-03` | -$71.02 | -0.71% | 5 | 2W / 3L | 40.0% |
| `2025-04` | -$108.06 | -1.08% | 8 | 3W / 5L | 37.5% |
| `2025-05` | +$64.08 | +0.64% | 7 | 4W / 3L | 57.1% |
| `2025-06` | -$251.04 | -2.51% | 8 | 2W / 6L | 25.0% |
| `2025-07` | +$483.92 | +4.84% | 10 | 8W / 2L | 80.0% |
| `2025-08` | +$308.10 | +3.08% | 5 | 4W / 1L | 80.0% |
| `2025-09` | -$326.16 | -3.26% | 8 | 2W / 6L | 25.0% |
| `2025-10` | +$179.14 | +1.79% | 7 | 4W / 3L | 57.1% |
| `2025-11` | +$536.86 | +5.37% | 12 | 8W / 4L | 66.7% |
| `2025-12` | -$1.98 | -0.02% | 7 | 3W / 4L | 42.9% |
| `2026-01` | +$364.96 | +3.65% | 8 | 5W / 3L | 62.5% |
| `2026-02` | -$55.02 | -0.55% | 3 | 1W / 2L | 33.3% |
| `2026-03` | +$41.04 | +0.41% | 4 | 2W / 2L | 50.0% |
| `2026-04` | -$83.04 | -0.83% | 3 | 1W / 2L | 33.3% |
| `2026-05` | +$63.12 | +0.63% | 13 | 6W / 7L | 46.2% |
| `2026-06` | +$240.10 | +2.40% | 12 | 6W / 6L | 50.0% |
| `2026-07` | +$128.94 | +1.29% | 15 | 7W / 8L | 46.7% |
| `2026-08` | +$11.02 | +0.11% | 10 | 4W / 6L | 40.0% |
| `2026-09` | +$424.06 | +4.24% | 9 | 6W / 3L | 66.7% |
| `2026-10` | +$352.12 | +3.52% | 14 | 8W / 6L | 57.1% |

---

### 4. FTMO 2-Step Challenge Simulation

* **Simulation Methodology:** Starting every single trading day over the 4-year period with fresh $10,000 capital. Target = +10.0% (+$1,000). Fail rule = Loss >= 5.0% in single day or Balance <= $9,000.
* **Result:**
  * **Pass Rate:** **92.9%** (Passed challenge successfully)
  * **Breach / Fail Rate:** **0.0%** (Never breached the hard limit in 4 years)
  * **Open / In Progress:** 7.1%
  * **Median Days to Pass Target:** **315 Trading Days**
