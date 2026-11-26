-- =============================================================
-- 02_staging.sql — limpeza, padronização e flags de qualidade
-- =============================================================

-- Parâmetros do relatório (fim da base de pedidos e janelas de análise)
DROP TABLE IF EXISTS ref_parametros;
CREATE TABLE ref_parametros (chave TEXT PRIMARY KEY, valor TEXT);
INSERT INTO ref_parametros VALUES
    ('fim_base_pedidos', '2018-08-31'),  -- última data com pedidos completos
    ('janela_conversao_dias', '60'),
    ('janela_ativacao_dias', '60');

DROP VIEW IF EXISTS stg_leads;
CREATE VIEW stg_leads AS
SELECT
    m.mql_id,
    date(m.first_contact_date)                         AS data_contato,
    strftime('%Y-%m', m.first_contact_date)            AS mes_contato,
    COALESCE(NULLIF(TRIM(m.origin), ''), 'unknown')    AS origem,
    m.landing_page_id,
    d.seller_id,
    d.sdr_id,
    d.sr_id,
    datetime(d.won_date)                               AS data_ganho,
    strftime('%Y-%m', d.won_date)                      AS mes_ganho,
    COALESCE(d.business_segment, 'nao_informado')      AS segmento,
    COALESCE(d.lead_type, 'nao_informado')             AS tipo_lead,
    COALESCE(d.business_type, 'nao_informado')        AS tipo_negocio,
    CASE WHEN d.mql_id IS NULL THEN 0 ELSE 1 END       AS ganho,
    CAST(julianday(date(d.won_date)) - julianday(date(m.first_contact_date)) AS INTEGER) AS ciclo_dias,
    -- flag de qualidade: negócio "ganho" antes do primeiro contato
    CASE WHEN d.won_date IS NOT NULL
          AND date(d.won_date) < date(m.first_contact_date) THEN 1 ELSE 0 END AS flag_ciclo_negativo
FROM raw_mql m
LEFT JOIN raw_closed_deals d ON d.mql_id = m.mql_id;

DROP VIEW IF EXISTS stg_vendas;
CREATE VIEW stg_vendas AS
SELECT
    order_id, order_item_id, seller_id,
    date(order_purchase_timestamp)           AS data_pedido,
    strftime('%Y-%m', order_purchase_timestamp) AS mes_pedido,
    price                                    AS valor_item,
    freight_value                            AS frete
FROM raw_vendas_sellers
WHERE order_status NOT IN ('canceled', 'unavailable')
  AND date(order_purchase_timestamp) <= (SELECT valor FROM ref_parametros WHERE chave = 'fim_base_pedidos');
