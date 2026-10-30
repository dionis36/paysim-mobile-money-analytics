-- 1. Pass-Through Account Detection (Sequential Sweeps)
-- Uses LEAD() to isolate accounts that receive a TRANSFER and execute a full CASH_OUT within a 2-hour window
WITH SequentialActivity AS (
    SELECT
        nameorig,
        step,
        day_num,
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
    nameorig as pass_through_account,
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

-- 2. Transaction Splitting Detection
-- Groups volumes by a 24-hour rolling window to find accounts executing 3+ high-value transfers to evade limits
WITH DailyTransfers AS (
    SELECT
        day_num,
        nameorig,
        COUNT(*) as transfer_count,
        ROUND(SUM(amount), 2) as daily_split_volume
    FROM vw_capital_flight
    WHERE type = 'TRANSFER'
    GROUP BY day_num, nameorig
)
SELECT
    day_num,
    transfer_count as transfers_in_24h,
    COUNT(nameorig) as number_of_evasion_accounts,
    SUM(daily_split_volume) as total_volume_exposed_usd
FROM DailyTransfers
WHERE transfer_count >= 3
GROUP BY day_num, transfer_count
ORDER BY transfer_count DESC, total_volume_exposed_usd DESC;

-- 3. Absolute Corporate Capital Flight
-- Quantifies the exact volume of illicit capital successfully converted to physical currency per day
SELECT
    day_num,
    COUNT(*) as fraudulent_cash_outs,
    ROUND(SUM(amount), 2) as physical_cash_lost_usd
FROM vw_capital_flight
WHERE type = 'CASH_OUT'
  AND isfraud = 1
GROUP BY day_num
ORDER BY day_num ASC;
