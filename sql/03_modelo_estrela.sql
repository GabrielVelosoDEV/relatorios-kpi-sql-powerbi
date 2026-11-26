-- =============================================================
-- 03_modelo_estrela.sql — modelo dimensional para o Power BI
-- =============================================================

-- Calendário contínuo cobrindo todo o período
DROP TABLE IF EXISTS dim_calendario;
CREATE TABLE dim_calendario AS
WITH RECURSIVE dias(d) AS (
    SELECT date('2017-06-01')
    UNION ALL SELECT date(d, '+1 day') FROM dias WHERE d < date('2018-12-31')
)
SELECT
    d                                   AS data,
    CAST(strftime('%Y', d) AS INTEGER)  AS ano,
    CAST(strftime('%m', d) AS INTEGER)  AS mes,
    strftime('%Y-%m', d)                AS ano_mes,
    ((CAST(strftime('%m', d) AS INTEGER) - 1) / 3) + 1 AS trimestre,
    CASE CAST(strftime('%w', d) AS INTEGER)
        WHEN 0 THEN 'dom' WHEN 1 THEN 'seg' WHEN 2 THEN 'ter' WHEN 3 THEN 'qua'
        WHEN 4 THEN 'qui' WHEN 5 THEN 'sex' ELSE 'sab' END AS dia_semana
FROM dias;

-- Dimensões com chaves curtas e nomes legíveis (os IDs originais são hashes)
DROP TABLE IF EXISTS dim_sdr;
CREATE TABLE dim_sdr AS
SELECT sdr_id,
       'SDR ' || printf('%02d', ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, sdr_id)) AS sdr_nome
FROM stg_leads WHERE sdr_id IS NOT NULL GROUP BY sdr_id;

DROP TABLE IF EXISTS dim_sr;
CREATE TABLE dim_sr AS
SELECT sr_id,
       'Vendedor ' || printf('%02d', ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, sr_id)) AS sr_nome
FROM stg_leads WHERE sr_id IS NOT NULL GROUP BY sr_id;

DROP TABLE IF EXISTS dim_origem;
CREATE TABLE dim_origem AS
SELECT DISTINCT origem,
       CASE
           WHEN origem IN ('organic_search', 'direct_traffic', 'referral') THEN 'Orgânico'
           WHEN origem IN ('paid_search', 'display', 'social', 'other_publicities') THEN 'Mídia'
           WHEN origem = 'email' THEN 'E-mail'
           ELSE 'Outros/Desconhecido'
       END AS grupo_origem
FROM stg_leads;

-- Fato de leads (grão: 1 linha por MQL)
DROP TABLE IF EXISTS fct_leads;
CREATE TABLE fct_leads AS
SELECT
    l.mql_id, l.data_contato, l.mes_contato, l.origem,
    l.ganho, l.data_ganho, date(l.data_ganho) AS data_ganho_dia, l.mes_ganho, l.ciclo_dias, l.flag_ciclo_negativo,
    CASE WHEN l.ganho = 1 AND l.flag_ciclo_negativo = 0
          AND l.ciclo_dias <= (SELECT CAST(valor AS INTEGER) FROM ref_parametros WHERE chave = 'janela_conversao_dias')
         THEN 1 ELSE 0 END AS ganho_60d,
    l.seller_id, l.segmento, l.tipo_lead, l.tipo_negocio,
    s.sdr_nome, r.sr_nome
FROM stg_leads l
LEFT JOIN dim_sdr s ON s.sdr_id = l.sdr_id
LEFT JOIN dim_sr  r ON r.sr_id  = l.sr_id;

CREATE INDEX idx_fct_leads_mes ON fct_leads(mes_contato);

-- Fato de vendas mensais dos sellers conquistados (grão: seller x mês)
DROP TABLE IF EXISTS fct_vendas_sellers;
CREATE TABLE fct_vendas_sellers AS
SELECT
    v.seller_id, v.mes_pedido, v.mes_pedido || '-01' AS data_mes,
    COUNT(DISTINCT v.order_id)  AS pedidos,
    ROUND(SUM(v.valor_item), 2) AS gmv
FROM stg_vendas v
GROUP BY v.seller_id, v.mes_pedido;

-- Dimensão de sellers conquistados (1 linha por seller)
DROP TABLE IF EXISTS dim_seller;
CREATE TABLE dim_seller AS
SELECT seller_id, segmento, tipo_lead, tipo_negocio, sdr_nome, sr_nome, data_ganho_dia, mes_ganho
FROM fct_leads WHERE ganho = 1;
