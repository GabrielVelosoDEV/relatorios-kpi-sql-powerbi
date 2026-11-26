# Modelo do Power BI

O modelo segue o esquema estrela gerado por [`sql/03_modelo_estrela.sql`](../sql/03_modelo_estrela.sql).
As tabelas ficam em [`dados/`](dados/) e são atualizadas a cada execução do pipeline.

## Tabelas

| Tabela | Tipo | Grão | Linhas |
|---|---|---|---:|
| `fct_leads` | fato | 1 linha por lead qualificado (MQL) | 8.000 |
| `fct_vendas_sellers` | fato | 1 linha por seller x mês de venda | 1.029 |
| `dim_calendario` | dimensão | 1 linha por dia (jun/2017 a dez/2018) | 579 |
| `dim_origem` | dimensão | origem do lead e grupo (Orgânico, Mídia, E-mail...) | 10 |
| `dim_sdr` | dimensão | pré-vendedor (SDR) | 32 |
| `dim_sr` | dimensão | vendedor (SR) | 22 |
| `dim_seller` | dimensão | seller conquistado | 842 |

## Relacionamentos

| De (1) | Para (*) | Ativo |
|---|---|---|
| `dim_calendario[data]` | `fct_leads[data_contato]` | sim |
| `dim_calendario[data]` | `fct_leads[data_ganho_dia]` | não (usado via `USERELATIONSHIP`) |
| `dim_calendario[data]` | `fct_vendas_sellers[data_mes]` | sim |
| `dim_origem[origem]` | `fct_leads[origem]` | sim |
| `dim_sdr[sdr_nome]` | `fct_leads[sdr_nome]` | sim |
| `dim_sr[sr_nome]` | `fct_leads[sr_nome]` | sim |
| `dim_seller[seller_id]` | `fct_vendas_sellers[seller_id]` | sim |

```
                 dim_origem    dim_sdr    dim_sr
                       \         |         /
 dim_calendario ──────── fct_leads ────────
        │
        └────────── fct_vendas_sellers ──── dim_seller
```

## Como montar o arquivo .pbix

1. No Power BI Desktop, crie uma **Consulta nula** para cada bloco de [`consultas_power_query.pq`](consultas_power_query.pq)
   e dê a ela o nome indicado no comentário.
2. Em **Modelo**, crie os relacionamentos da tabela acima e marque `dim_calendario` como tabela de datas.
3. Crie a tabela `_Medidas` e adicione as medidas de [`medidas.dax`](medidas.dax).
4. Páginas sugeridas:
   - **Visão executiva:** cartões de Leads, Conversão 60d %, Var. Conversão p.p., Negócios fechados no mês e Ciclo mediano;
     linha de Leads e Conversão por `dim_calendario[ano_mes]`.
   - **Origem:** matriz de `dim_origem` com Leads, Negócios 60d e Conversão; cartão de Leads sem origem %.
   - **Equipe:** ranking de `dim_sdr` e `dim_sr` por Negócios fechados no mês e Ciclo médio.
   - **Sellers:** GMV e GMV por seller conquistado por `dim_seller[tipo_lead]` e `dim_seller[segmento]`.

Como as consultas leem os CSVs direto do GitHub, o botão **Atualizar** do Power BI traz a versão mais recente
dos dados sem precisar trocar arquivos.
