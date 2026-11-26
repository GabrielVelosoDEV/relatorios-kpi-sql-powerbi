# Relatórios de KPIs comerciais com SQL e Power BI

**Automação de relatórios de indicadores de um funil de vendas real: modelo estrela em SQL, relatório mensal com alertas
gerado automaticamente e modelo pronto para o Power BI.**

[![Relatório de KPIs](https://github.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/actions/workflows/relatorio.yml/badge.svg)](https://github.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi/actions/workflows/relatorio.yml)
![SQL](https://img.shields.io/badge/SQL-SQLite-003B57)
![Power BI](https://img.shields.io/badge/Power%20BI-DAX%20%2B%20Power%20Query-F2C811)
![Python](https://img.shields.io/badge/Python-3.12-blue)

🔗 **Painel do relatório:** https://gabrielvelosodev.github.io/relatorios-kpi-sql-powerbi/

---

## O problema

Uma área comercial que recebe milhares de leads por mês precisa responder rápido, e sempre do mesmo jeito: quantos
leads entraram, quantos viraram cliente, quais canais funcionam, quanto tempo leva para fechar e se os clientes
conquistados estão vendendo. Montar isso à mão em planilha todo mês é lento e sujeito a erro.

Este projeto automatiza o processo com o **funil de marketing real da Olist**: 8.000 leads qualificados (jun/2017 a
mai/2018), 842 negócios fechados por 32 SDRs e 22 vendedores, e as vendas desses sellers no marketplace.

## O que o projeto entrega

1. **Modelo em SQL em camadas** (raw → staging → modelo estrela → KPIs), com regras de negócio e flags de qualidade.
2. **Relatório mensal automático** em Markdown ([`reports/mensal/`](reports/mensal/)) e em um
   [painel web](https://gabrielvelosodev.github.io/relatorios-kpi-sql-powerbi/) com seletor de mês, comparação com o mês anterior
   e **alertas gerados por regras** (queda de conversão, canal com desempenho ruim, leads sem origem, inconsistências).
3. **Modelo para o Power BI** ([`powerbi/`](powerbi/)): tabelas do esquema estrela em CSV, consultas do Power Query que leem
   os dados direto do GitHub, 17 medidas DAX e a documentação dos relacionamentos.
4. **GitHub Actions** que testa, reconstrói o modelo e regenera os relatórios a cada mudança.

## Principais resultados

| Indicador | Valor |
|---|---|
| Leads qualificados | 8.000 |
| Negócios fechados | 842 (10,5%) |
| Conversão em até 60 dias (leads de jan a mai/2018) | **10,6%** |
| Ciclo de vendas (mediana) | **14 dias** (média de 48, puxada por negócios longos) |
| Sellers que venderam nos primeiros 60 dias | **32,6%** |
| GMV dos sellers conquistados (até ago/2018) | R$ 674 mil |

**1. Os canais pagos de redes sociais e o e-mail quase não convertem.** Redes sociais respondem por 17% dos leads, mas
convertem 3,7% em 60 dias; e-mail converte 2,2%. Busca orgânica e paga ficam perto de 9%.

**2. A maior conversão está nos leads sem origem identificada (13,8%).** Isso indica falha de rastreamento: parte dos
melhores leads não está sendo atribuída ao canal certo, o que distorce qualquer decisão de investimento em mídia.

**3. Conversão caiu de 12,0% para 7,8% em maio/2018** — o relatório do mês sinaliza a queda automaticamente, junto com os
canais que puxaram o resultado para baixo.

**4. Fechar não é o mesmo que ativar.** Só um terço dos sellers conquistados vende nos primeiros 60 dias. Sellers
`online_big` ativam 47%; `offline` e `industry`, menos de 21%. O onboarding desses perfis é o gargalo.

**5. Concentração na equipe.** O SDR com mais negócios fechou 140 (17% do total), quase o dobro do segundo.

## Decisões de análise

- **Conversão em janela fixa de 60 dias.** Leads mais recentes tiveram menos tempo para fechar; comparar a conversão "até
  hoje" de meses diferentes seria injusto. A janela fixa deixa os meses comparáveis.
- **Relatórios só a partir de jan/2018.** Os primeiros negócios do funil são de dez/2017; antes disso a operação de vendas
  ainda não estava ativa e a conversão de 2017 não é comparável.
- **Ativação só para sellers com 60 dias observáveis.** A base de pedidos termina em ago/2018; sellers ganhos depois de
  jul/2018 ficam fora do cálculo para não parecerem "inativos" por falta de dados.
- **Qualidade de dados explícita.** Um negócio tem data de ganho anterior ao primeiro contato; ele é sinalizado
  (`flag_ciclo_negativo`) e excluído do cálculo de ciclo, em vez de ser apagado.

## Arquitetura

```
data/raw/*.csv.gz
      │  src/build.py
      ▼
SQLite ├── raw_*                 sql/01_raw.sql
       ├── stg_*                 sql/02_staging.sql        limpeza, parâmetros, flags
       ├── dim_* / fct_*         sql/03_modelo_estrela.sql modelo estrela
       └── vw_kpi_*              sql/04_kpis.sql           indicadores
      │
      ├──► powerbi/dados/*.csv   modelo para o Power BI (Power Query + DAX)
      │  src/report.py
      ├──► reports/mensal/*.md   relatório mensal com alertas
      └──► docs/index.html       painel publicado no GitHub Pages
```

## Como rodar

```bash
git clone https://github.com/GabrielVelosoDEV/relatorios-kpi-sql-powerbi.git
cd relatorios-kpi-sql-powerbi
python src/build.py      # monta o banco e exporta o modelo do Power BI
python src/report.py     # gera os relatórios mensais e o painel
pip install pytest && pytest -q
```

Sem dependências externas além da biblioteca padrão do Python (`pytest` só para os testes).

Para montar o arquivo do Power BI, siga [`powerbi/MODELO.md`](powerbi/MODELO.md).

## Testes

11 testes verificam carga completa, unicidade de chaves, integridade entre leads e negócios, consistência entre as
janelas de conversão, tratamento do ciclo negativo, reconciliação dos KPIs com a tabela fato, limite de datas das vendas,
continuidade do calendário e as regras de alerta.

## Dados e licença

Dados: [Marketing Funnel by Olist](https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist) e
[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), licença
CC BY-NC-SA 4.0 (ver [`data/raw/LICENSE-DADOS.md`](data/raw/LICENSE-DADOS.md)). Código sob licença MIT.

---

Feito por **Gabriel Veloso** · [LinkedIn](https://www.linkedin.com/in/gabrielvelosodev/) · [GitHub](https://github.com/GabrielVelosoDEV)
