# Project Log: PaySim Data Analysis

## Phase 1: Database Setup
**Task:** Create the database, set up the table structure, and import the raw dataset.

1. Created a new database named `paysim_db` in PostgreSQL using DBeaver.
2. Created the `raw_transactions` table. I used `DECIMAL(18,2)` for all monetary columns to ensure no numbers were rounded off or lost.
3. Imported the 6.3 million rows of data.
4. Added B-Tree indexes to commonly used columns to speed up future queries.

```sql
CREATE DATABASE paysim_db;

CREATE TABLE raw_transactions (
    step INT,
    type VARCHAR(20),
    amount DECIMAL(18, 2),
    nameOrig VARCHAR(50),
    oldbalanceOrg DECIMAL(18, 2),
    newbalanceOrig DECIMAL(18, 2),
    nameDest VARCHAR(50),
    oldbalanceDest DECIMAL(18, 2),
    newbalanceDest DECIMAL(18, 2),
    isFraud SMALLINT,
    isFlaggedFraud SMALLINT
);

CREATE INDEX idx_trans_type ON raw_transactions(type);
CREATE INDEX idx_name_orig ON raw_transactions(nameOrig);
CREATE INDEX idx_name_dest ON raw_transactions(nameDest);
CREATE INDEX idx_step ON raw_transactions(step);
```

## Phase 2: Data Exploration & Quality Checks
**Task:** Check basic transaction volumes, verify account balances, and review the existing fraud flags.

**1. Baseline Transaction Volumes**
Query to check how many transactions exist for each type and their total value.

```sql
SELECT 
    type,
    COUNT(*) as transaction_count,
    ROUND(SUM(amount), 2) as total_volume_usd,
    ROUND(AVG(amount), 2) as avg_transaction_value
FROM raw_transactions
GROUP BY type
ORDER BY total_volume_usd DESC;
```
| type | transaction_count | total_volume_usd | avg_transaction_value |
| :--- | :--- | :--- | :--- |
| TRANSFER | 532,909 | 485,291,987,263.17 | 910,647.01 |
| CASH_OUT | 2,237,500 | 394,412,995,224.49 | 176,273.96 |
| CASH_IN | 1,399,284 | 236,367,391,912.46 | 168,920.24 |
| PAYMENT | 2,151,495 | 28,093,371,138.37 | 13,057.60 |
| DEBIT | 41,432 | 227,199,221.28 | 5,483.67 |

**2. Account Balance Check**
Query to find records where the starting balance minus the transaction amount does not equal the new balance.
*(Result: Found thousands of unmatched rows, indicating a difference in how balances are recorded in this dataset).*

**3. Existing Fraud Flag Performance**
Query to compare actual fraud (`isFraud`) against the dataset's built-in alert system (`isFlaggedFraud`).

```sql
SELECT 
    isfraud as actual_fraud,
    isflaggedfraud as system_flagged,
    COUNT(*) as transaction_count,
    ROUND(SUM(amount), 2) as total_exposure_usd
FROM raw_transactions
GROUP BY isfraud, isflaggedfraud
ORDER BY actual_fraud DESC, system_flagged DESC;
```
| actual_fraud | system_flagged | transaction_count | total_exposure_usd |
| :--- | :--- | :--- | :--- |
| 1 | 1 | 16 | 77,785,563.69 |
| 1 | 0 | 8,197 | 11,978,629,864.15 |
| 0 | 0 | 6,354,407 | 1,132,336,529,331.93 |

## Phase 3: Data Preparation
**Task:** Convert the `step` column into usable days and hours, and filter the data for easier analysis.

**Performance Note:** Trying to run an `UPDATE` command to add day and hour columns directly to the 6.3 million row table was too slow (it took over 10 minutes). I stopped the process and used a database view instead. A view calculates these columns instantly when queried, saving system resources.

```sql
-- 1. Create a view to calculate days and hours
CREATE VIEW v_operational_analytics AS
SELECT 
    *,
    ((step - 1) / 24) + 1 AS day_num,
    (step - 1) % 24 AS hour_of_day
FROM raw_transactions;

-- 2. Add indexes to support the math in the view
CREATE INDEX idx_raw_day_expr ON raw_transactions ((((step - 1) / 24) + 1));
CREATE INDEX idx_raw_hour_expr ON raw_transactions (((step - 1) % 24));

-- 3. Create a filtered view for only Transfers and Cash-Outs to speed up fraud queries
CREATE OR REPLACE VIEW vw_capital_flight AS
SELECT 
    step, day_num, hour_of_day, type, amount, nameorig, oldbalanceorg,
    newbalanceorig, namedest, oldbalancedest, newbalancedest, isfraud, isflaggedfraud
FROM v_operational_analytics
WHERE type IN ('TRANSFER', 'CASH_OUT');
```

## Phase 4: Fraud and Transaction Analysis
**Task:** Use SQL to find specific transaction patterns.

**1. Rapid Transfer and Cash-Out Pattern**
Used the `LEAD()` window function to find accounts that received a transfer and fully cashed it out within 2 hours.

*Result:* Found account `C635739031`, which transferred in $1,965,786.11 and cashed out two hours later, leaving a zero balance. This shows an unusual transaction pattern worth investigating.

**2. Transfer Frequency Analysis**
Checked if accounts were making 3 or more high-value transfers in a single day.

*Result:* Zero accounts matched this pattern. This indicates that users in this dataset generally do not make multiple large transfers from the same account in one day.

**3. Daily Fraudulent Cash-Out Activity**
Checked the total amount of money lost per day to confirmed fraudulent cash-outs.

*Result:* Losses ranged from roughly 105 million to 316 million per day across the 31-day period.

## Phase 5: Data Extraction for Tableau
**Task:** Export grouped data to CSV files so the Tableau dashboard runs smoothly.

Exported 5 specific datasets:
1. `hourly_network_summary.csv` (Overall volume and fraud by hour)
2. `confirmed_fraud_details.csv` (Row-level details for fraud records)
3. `merchant_daily_volume.csv` (Money received by merchants)
4. `rapid_cashout_anomalies.csv` (The 2-hour cash-out findings)
5. `customer_transfer_frequency.csv` (How often accounts make transfers)

## Phase 6-8: Tableau Dashboard Assembly
**Task:** Build the visual presentation.

1. **Setup:** Connected all 5 CSV files as separate data sources to keep the workbook light.
2. **Tab 1 (Executive Overview):** Built summary numbers and a line chart showing daily normal volume versus daily fraud volume.
3. **Tab 2 (Fraud Forensics):** Built a scatter plot for transfer frequency and a timeline chart for the rapid cash-out account.
4. **Tab 3 (Operations):** Built a heatmap to show the busiest hours and a treemap to show which merchants handle the most volume.