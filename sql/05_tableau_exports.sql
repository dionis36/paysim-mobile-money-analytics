-- Extract 1: hourly_network_summary.csv
-- Powers time-series charts, top-level KPIs, and peak-hour heatmaps
WITH HourlyVolume AS (
    SELECT 
        ((step - 1) / 24) + 1 AS day_num,
        (step - 1) % 24 AS hour_of_day,
        COUNT(*) as total_transactions,
        SUM(amount) as total_volume_usd
    FROM raw_transactions
    GROUP BY ((step - 1) / 24) + 1, (step - 1) % 24
),
HourlyFraud AS (
    SELECT 
        ((step - 1) / 24) + 1 AS day_num,
        (step - 1) % 24 AS hour_of_day,
        COUNT(*) as fraudulent_transactions,
        SUM(amount) as cash_lost_usd
    FROM vw_capital_flight
    WHERE isfraud = 1
    GROUP BY ((step - 1) / 24) + 1, (step - 1) % 24
)
SELECT 
    v.day_num,
    v.hour_of_day,
    v.total_transactions,
    v.total_volume_usd,
    COALESCE(f.fraudulent_transactions, 0) as fraud_flags,
    COALESCE(f.cash_lost_usd, 0) as total_cash_lost_usd,
    ROUND((COALESCE(f.cash_lost_usd, 0) / v.total_volume_usd) * 100, 4) as fraud_loss_percentage
FROM HourlyVolume v
LEFT JOIN HourlyFraud f 
    ON v.day_num = f.day_num AND v.hour_of_day = f.hour_of_day
ORDER BY v.day_num ASC, v.hour_of_day ASC;

-- Extract 2: confirmed_fraud_details.csv
-- Provides transaction-level details of confirmed fraud for micro-drill-downs
SELECT 
    step,
    ((step - 1) / 24) + 1 AS day_num,
    type,
    amount,
    nameorig,
    namedest,
    oldbalanceorg,
    newbalanceorig
FROM vw_capital_flight
WHERE isfraud = 1;

-- Extract 3: merchant_daily_volume.csv
-- Tracks merchant health for the Agent Liquidity flow chart
SELECT 
    ((step - 1) / 24) + 1 AS day_num,
    namedest as merchant_id,
    COUNT(*) as transaction_count,
    ROUND(SUM(amount), 2) as daily_inflow_usd
FROM raw_transactions
WHERE namedest LIKE 'M%'
GROUP BY ((step - 1) / 24) + 1, namedest;

-- Extract 4: rapid_cashout_anomalies.csv
-- Exposes specific zero-balance sweep anomalies using Window Functions
WITH SequentialActivity AS (
    SELECT 
        nameorig,
        step,
        ((step - 1) / 24) + 1 AS day_num,
        type,
        amount,
        oldbalanceorg,
        newbalanceorig,
        LEAD(type) OVER (PARTITION BY nameorig ORDER BY step) as next_type,
        LEAD(step) OVER (PARTITION BY nameorig ORDER BY step) as next_step,
        LEAD(amount) OVER (PARTITION BY nameorig ORDER BY step) as next_amount
    FROM vw_capital_flight
)
SELECT 
    nameorig as anomaly_account,
    step as transfer_hour,
    next_step as cashout_hour,
    (next_step - step) as hours_between_sweep,
    amount as initial_transfer_amount,
    next_amount as cashout_amount
FROM SequentialActivity
WHERE type = 'TRANSFER' 
  AND next_type = 'CASH_OUT'
  AND (oldbalanceorg - amount) = 0 
  AND (next_step - step) <= 2
ORDER BY amount DESC;

-- Extract 5: customer_transfer_frequency.csv
-- Powers the Scatter Plot (Frequency vs. Avg Amount) to visualize structuring
SELECT 
    ((step - 1) / 24) + 1 AS day_num,
    nameorig,
    COUNT(*) as transfer_count,
    ROUND(AVG(amount), 2) as avg_transfer_amount,
    ROUND(SUM(amount), 2) as daily_structured_volume
FROM vw_capital_flight
WHERE type = 'TRANSFER'
GROUP BY ((step - 1) / 24) + 1, nameorig;