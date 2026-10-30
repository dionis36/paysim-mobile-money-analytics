-- Initialize the database
CREATE DATABASE paysim_db;

-- Create the raw transactions table
-- DECIMAL(18,2) is used to prevent precision loss on large financial values
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

-- Apply B-Tree indexing on frequently filtered and joined columns
CREATE INDEX idx_trans_type ON raw_transactions(type);
CREATE INDEX idx_name_orig ON raw_transactions(nameOrig);
CREATE INDEX idx_name_dest ON raw_transactions(nameDest);
CREATE INDEX idx_step ON raw_transactions(step);
