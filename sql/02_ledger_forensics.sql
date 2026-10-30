-- 1. Baseline Distributions: Map total volume and monetary value by transaction type
SELECT
    type,
    COUNT(*) as transaction_count,
    ROUND(SUM(amount), 2) as total_volume_usd,
    ROUND(AVG(amount), 2) as avg_transaction_value
FROM raw_transactions
GROUP BY type
ORDER BY total_volume_usd DESC;

-- 2. Ledger Arithmetic Validation: Expose broken ledger rows and unreconciled amounts
SELECT
    type,
    COUNT(*) as broken_ledger_rows,
    ROUND(SUM(ABS((oldbalanceorg - amount) - newbalanceorig)), 2) as total_unreconciled_amount_usd
FROM raw_transactions
WHERE type IN ('CASH_OUT', 'TRANSFER', 'PAYMENT')
  AND (oldbalanceorg - amount) != newbalanceorig
GROUP BY type
ORDER BY broken_ledger_rows DESC;

-- 3. Legacy System Evaluation: Compare actual confirmed fraud against the telecom's automated flags
SELECT
    isfraud as actual_fraud,
    isflaggedfraud as system_flagged,
    COUNT(*) as transaction_count,
    ROUND(SUM(amount), 2) as total_exposure_usd
FROM raw_transactions
GROUP BY isfraud, isflaggedfraud
ORDER BY actual_fraud DESC, system_flagged DESC;
