-- 1. Temporal Transformation (Virtualized)
-- Computes day_num and hour_of_day on the fly using modulo arithmetic to avoid I/O bottlenecks
CREATE VIEW v_operational_analytics AS
SELECT
    *,
    ((step - 1) / 24) + 1 AS day_num,
    (step - 1) % 24 AS hour_of_day
FROM raw_transactions;

-- Apply Expression Indexes to the base table to support the virtual view
CREATE INDEX idx_raw_day_expr ON raw_transactions ((((step - 1) / 24) + 1));
CREATE INDEX idx_raw_hour_expr ON raw_transactions (((step - 1) % 24));
CREATE INDEX idx_raw_type_fraud ON raw_transactions (type, isFraud);

-- 2. High-Risk Transaction View (Capital Flight Isolation)
-- Limits the analytical dataset strictly to peer-to-peer transfers and cash-outs
CREATE OR REPLACE VIEW vw_capital_flight AS
SELECT
    step,
    day_num,
    hour_of_day,
    type,
    amount,
    nameorig,
    oldbalanceorg,
    newbalanceorig,
    namedest,
    oldbalancedest,
    newbalancedest,
    isfraud,
    isflaggedfraud
FROM v_operational_analytics
WHERE type IN ('TRANSFER', 'CASH_OUT');
