// =============================================================
// Consultas do Power Query (linguagem M)
// Cada bloco vira uma consulta: Página Inicial > Obter dados > Consulta nula >
// Editor Avançado, cole o bloco e renomeie a consulta com o nome indicado.
// Os CSVs são lidos direto do GitHub, então 'Atualizar' traz a versão mais recente.
// =============================================================

// ---------- Consulta: dim_calendario
let
    Fonte = Csv.Document(
        Web.Contents("https://raw.githubusercontent.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/main/powerbi/dados/dim_calendario.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Cabecalhos = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipos = Table.TransformColumnTypes(Cabecalhos, {
        {"data", type date},
        {"ano", Int64.Type},
        {"mes", Int64.Type},
        {"ano_mes", type text},
        {"trimestre", Int64.Type},
        {"dia_semana", type text}
    }, "en-US")
in
    Tipos

// ---------- Consulta: dim_origem
let
    Fonte = Csv.Document(
        Web.Contents("https://raw.githubusercontent.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/main/powerbi/dados/dim_origem.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Cabecalhos = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipos = Table.TransformColumnTypes(Cabecalhos, {
        {"origem", type text},
        {"grupo_origem", type text}
    }, "en-US")
in
    Tipos

// ---------- Consulta: dim_sdr
let
    Fonte = Csv.Document(
        Web.Contents("https://raw.githubusercontent.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/main/powerbi/dados/dim_sdr.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Cabecalhos = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipos = Table.TransformColumnTypes(Cabecalhos, {
        {"sdr_id", type text},
        {"sdr_nome", type text}
    }, "en-US")
in
    Tipos

// ---------- Consulta: dim_sr
let
    Fonte = Csv.Document(
        Web.Contents("https://raw.githubusercontent.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/main/powerbi/dados/dim_sr.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Cabecalhos = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipos = Table.TransformColumnTypes(Cabecalhos, {
        {"sr_id", type text},
        {"sr_nome", type text}
    }, "en-US")
in
    Tipos

// ---------- Consulta: dim_seller
let
    Fonte = Csv.Document(
        Web.Contents("https://raw.githubusercontent.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/main/powerbi/dados/dim_seller.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Cabecalhos = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipos = Table.TransformColumnTypes(Cabecalhos, {
        {"seller_id", type text},
        {"segmento", type text},
        {"tipo_lead", type text},
        {"tipo_negocio", type text},
        {"sdr_nome", type text},
        {"sr_nome", type text},
        {"data_ganho_dia", type date},
        {"mes_ganho", type text}
    }, "en-US")
in
    Tipos

// ---------- Consulta: fct_leads
let
    Fonte = Csv.Document(
        Web.Contents("https://raw.githubusercontent.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/main/powerbi/dados/fct_leads.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Cabecalhos = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipos = Table.TransformColumnTypes(Cabecalhos, {
        {"mql_id", type text},
        {"data_contato", type date},
        {"mes_contato", type text},
        {"origem", type text},
        {"ganho", Int64.Type},
        {"data_ganho", type datetime},
        {"data_ganho_dia", type date},
        {"mes_ganho", type text},
        {"ciclo_dias", Int64.Type},
        {"flag_ciclo_negativo", Int64.Type},
        {"ganho_60d", Int64.Type},
        {"seller_id", type text},
        {"segmento", type text},
        {"tipo_lead", type text},
        {"tipo_negocio", type text},
        {"sdr_nome", type text},
        {"sr_nome", type text}
    }, "en-US")
in
    Tipos

// ---------- Consulta: fct_vendas_sellers
let
    Fonte = Csv.Document(
        Web.Contents("https://raw.githubusercontent.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/main/powerbi/dados/fct_vendas_sellers.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Cabecalhos = Table.PromoteHeaders(Fonte, [PromoteAllScalars = true]),
    Tipos = Table.TransformColumnTypes(Cabecalhos, {
        {"seller_id", type text},
        {"mes_pedido", type text},
        {"data_mes", type date},
        {"pedidos", Int64.Type},
        {"gmv", type number}
    }, "en-US")
in
    Tipos
