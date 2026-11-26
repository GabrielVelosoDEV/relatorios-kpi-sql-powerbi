-- =============================================================
-- 04_kpis.sql — indicadores prontos para relatório
-- =============================================================

-- KPIs mensais por mês de entrada do lead
DROP VIEW IF EXISTS vw_kpi_mensal;
CREATE VIEW vw_kpi_mensal AS
WITH base AS (
    SELECT mes_contato AS mes,
           COUNT(*)            AS leads,
           SUM(ganho)          AS negocios,
           SUM(ganho_60d)      AS negocios_60d
    FROM fct_leads
    GROUP BY mes_contato
)
SELECT
    mes, leads, negocios, negocios_60d,
    ROUND(100.0 * negocios_60d / leads, 2)                               AS conversao_60d_pct,
    ROUND(100.0 * (leads * 1.0 / LAG(leads) OVER (ORDER BY mes) - 1), 1) AS leads_var_mes_pct,
    ROUND(100.0 * negocios_60d / leads
        - LAG(100.0 * negocios_60d / leads) OVER (ORDER BY mes), 2)      AS conversao_var_pp
FROM base
ORDER BY mes;

-- Negócios fechados por mês de ganho
DROP VIEW IF EXISTS vw_negocios_mes;
CREATE VIEW vw_negocios_mes AS
SELECT mes_ganho AS mes,
       COUNT(*)                                        AS negocios,
       CAST(ROUND(AVG(ciclo_dias)) AS INTEGER)         AS ciclo_medio_dias
FROM fct_leads
WHERE ganho = 1 AND flag_ciclo_negativo = 0
GROUP BY mes_ganho
ORDER BY mes_ganho;

-- Conversão por origem
DROP VIEW IF EXISTS vw_kpi_origem;
CREATE VIEW vw_kpi_origem AS
SELECT
    f.origem, o.grupo_origem,
    COUNT(*)                                     AS leads,
    SUM(f.ganho_60d)                             AS negocios_60d,
    ROUND(100.0 * SUM(f.ganho_60d) / COUNT(*), 2) AS conversao_60d_pct,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_leads_pct
FROM fct_leads f
JOIN dim_origem o USING (origem)
GROUP BY f.origem, o.grupo_origem
ORDER BY leads DESC;

-- Ciclo de vendas: mediana via ordenação (SQLite não tem MEDIAN)
DROP VIEW IF EXISTS vw_ciclo;
CREATE VIEW vw_ciclo AS
WITH c AS (
    SELECT ciclo_dias,
           ROW_NUMBER() OVER (ORDER BY ciclo_dias) AS rn,
           COUNT(*) OVER () AS n
    FROM fct_leads WHERE ganho = 1 AND flag_ciclo_negativo = 0
)
SELECT
    (SELECT AVG(ciclo_dias) FROM c WHERE rn IN ((n + 1) / 2, (n + 2) / 2)) AS mediana_dias,
    (SELECT ROUND(AVG(ciclo_dias), 1) FROM c)                              AS media_dias,
    (SELECT ciclo_dias FROM c WHERE rn = CAST(0.75 * n AS INTEGER))        AS p75_dias,
    (SELECT COUNT(*) FROM fct_leads WHERE flag_ciclo_negativo = 1)         AS registros_ciclo_negativo;

-- Desempenho dos SDRs (pré-venda)
DROP VIEW IF EXISTS vw_kpi_sdr;
CREATE VIEW vw_kpi_sdr AS
SELECT sdr_nome,
       COUNT(*)                                AS negocios,
       CAST(ROUND(AVG(CASE WHEN flag_ciclo_negativo = 0 THEN ciclo_dias END)) AS INTEGER) AS ciclo_medio_dias,
       COUNT(DISTINCT segmento)                AS segmentos
FROM fct_leads WHERE ganho = 1
GROUP BY sdr_nome
ORDER BY negocios DESC;

-- Ativação: sellers ganhos até 60 dias antes do fim da base que venderam em até 60 dias
DROP VIEW IF EXISTS vw_ativacao_sellers;
CREATE VIEW vw_ativacao_sellers AS
WITH p AS (
    SELECT (SELECT valor FROM ref_parametros WHERE chave = 'fim_base_pedidos') AS fim,
           (SELECT CAST(valor AS INTEGER) FROM ref_parametros WHERE chave = 'janela_ativacao_dias') AS janela
),
elegiveis AS (
    SELECT f.seller_id, f.tipo_lead, date(f.data_ganho) AS d
    FROM fct_leads f, p
    WHERE f.ganho = 1 AND date(f.data_ganho) <= date(p.fim, '-' || p.janela || ' days')
),
ativos AS (
    SELECT DISTINCT e.seller_id
    FROM elegiveis e
    JOIN stg_vendas v ON v.seller_id = e.seller_id, p
    WHERE v.data_pedido BETWEEN e.d AND date(e.d, '+' || p.janela || ' days')
)
SELECT e.tipo_lead,
       COUNT(*) AS sellers_elegiveis,
       SUM(CASE WHEN a.seller_id IS NOT NULL THEN 1 ELSE 0 END) AS sellers_ativados,
       ROUND(100.0 * SUM(CASE WHEN a.seller_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS ativacao_60d_pct
FROM elegiveis e LEFT JOIN ativos a USING (seller_id)
GROUP BY e.tipo_lead
ORDER BY sellers_elegiveis DESC;

-- GMV gerado pelos sellers conquistados, por segmento
DROP VIEW IF EXISTS vw_gmv_segmento;
CREATE VIEW vw_gmv_segmento AS
SELECT f.segmento,
       COUNT(DISTINCT f.seller_id)                      AS sellers_ganhos,
       COUNT(DISTINCT v.seller_id)                      AS sellers_com_venda,
       ROUND(COALESCE(SUM(v.gmv), 0), 2)                AS gmv,
       ROUND(COALESCE(SUM(v.gmv), 0) / COUNT(DISTINCT f.seller_id), 2) AS gmv_por_seller_ganho
FROM fct_leads f
LEFT JOIN fct_vendas_sellers v ON v.seller_id = f.seller_id
WHERE f.ganho = 1
GROUP BY f.segmento
ORDER BY gmv DESC;
