-- =============================================================
-- 01_raw.sql — tabelas espelho dos arquivos de origem
-- =============================================================
DROP TABLE IF EXISTS raw_mql;
CREATE TABLE raw_mql (
    mql_id             TEXT PRIMARY KEY,
    first_contact_date TEXT NOT NULL,
    landing_page_id    TEXT,
    origin             TEXT
);

DROP TABLE IF EXISTS raw_closed_deals;
CREATE TABLE raw_closed_deals (
    mql_id                        TEXT PRIMARY KEY,
    seller_id                     TEXT NOT NULL,
    sdr_id                        TEXT,
    sr_id                         TEXT,
    won_date                      TEXT NOT NULL,
    business_segment              TEXT,
    lead_type                     TEXT,
    lead_behaviour_profile        TEXT,
    has_company                   TEXT,
    has_gtin                      TEXT,
    average_stock                 TEXT,
    business_type                 TEXT,
    declared_product_catalog_size REAL,
    declared_monthly_revenue      REAL
);

DROP TABLE IF EXISTS raw_vendas_sellers;
CREATE TABLE raw_vendas_sellers (
    order_id                 TEXT    NOT NULL,
    order_item_id            INTEGER NOT NULL,
    seller_id                TEXT    NOT NULL,
    order_status             TEXT,
    order_purchase_timestamp TEXT    NOT NULL,
    price                    REAL    NOT NULL,
    freight_value            REAL,
    PRIMARY KEY (order_id, order_item_id)
);
