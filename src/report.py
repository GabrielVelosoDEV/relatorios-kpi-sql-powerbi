"""Gera automaticamente o relatório mensal de KPIs comerciais.

Para cada mês fechado, produz:
  - reports/mensal/AAAA-MM.md   relatório em Markdown com comparação ao mês anterior e alertas
  - docs/index.html             painel web com seletor de mês (publicado no GitHub Pages)

Uso:
    python src/report.py            # requer data/funil.db (rode src/build.py antes)
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "funil.db"
OUT_MD = ROOT / "reports" / "mensal"
OUT_HTML = ROOT / "docs" / "index.html"

# meses com janela de 60 dias totalmente observada e operação de vendas ativa
MESES = ["2018-01", "2018-02", "2018-03", "2018-04", "2018-05"]

# regras de alerta
QUEDA_CONVERSAO_PP = 2.0      # queda de conversão maior que 2 p.p. vs mês anterior
ORIGEM_MIN_LEADS = 50         # só avalia origens com volume mínimo no mês
ORIGEM_CONV_BAIXA = 0.5       # origem convertendo menos da metade da média do mês

NOMES_ORIGEM = {
    "organic_search": "Busca orgânica", "paid_search": "Busca paga", "social": "Redes sociais",
    "unknown": "Não identificada", "direct_traffic": "Tráfego direto", "email": "E-mail",
    "referral": "Indicação", "other": "Outros", "display": "Display", "other_publicities": "Outras mídias",
}


def q(con: sqlite3.Connection, sql: str, params: tuple = ()) -> list[dict]:
    cur = con.execute(sql, params)
    cols = [c[0] for c in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def dados_mes(con: sqlite3.Connection, mes: str) -> dict:
    k = q(con, "SELECT * FROM vw_kpi_mensal WHERE mes = ?", (mes,))[0]
    ant = q(con, "SELECT * FROM vw_kpi_mensal WHERE mes < ? ORDER BY mes DESC LIMIT 1", (mes,))[0]
    origens = q(con, """
        SELECT origem, COUNT(*) AS leads, SUM(ganho_60d) AS negocios,
               ROUND(100.0 * SUM(ganho_60d) / COUNT(*), 2) AS conversao
        FROM fct_leads WHERE mes_contato = ? GROUP BY origem ORDER BY leads DESC""", (mes,))
    ganhos = q(con, """
        SELECT COUNT(*) AS negocios,
               CAST(ROUND(AVG(CASE WHEN flag_ciclo_negativo = 0 THEN ciclo_dias END)) AS INTEGER) AS ciclo
        FROM fct_leads WHERE ganho = 1 AND mes_ganho = ?""", (mes,))[0]
    sdrs = q(con, """
        SELECT sdr_nome, COUNT(*) AS negocios
        FROM fct_leads WHERE ganho = 1 AND mes_ganho = ?
        GROUP BY sdr_nome ORDER BY negocios DESC, sdr_nome LIMIT 5""", (mes,))
    segmentos = q(con, """
        SELECT segmento, COUNT(*) AS negocios
        FROM fct_leads WHERE ganho = 1 AND mes_ganho = ?
        GROUP BY segmento ORDER BY negocios DESC, segmento LIMIT 5""", (mes,))
    qualidade = q(con, """
        SELECT SUM(flag_ciclo_negativo) AS ciclo_negativo,
               SUM(CASE WHEN origem = 'unknown' THEN 1 ELSE 0 END) AS sem_origem
        FROM fct_leads WHERE mes_contato = ?""", (mes,))[0]
    return {"mes": mes, "kpi": k, "anterior": ant, "origens": origens, "ganhos": ganhos,
            "sdrs": sdrs, "segmentos": segmentos, "qualidade": qualidade}


def alertas(d: dict) -> list[str]:
    a = []
    k, ant = d["kpi"], d["anterior"]
    delta = k["conversao_60d_pct"] - ant["conversao_60d_pct"]
    if delta <= -QUEDA_CONVERSAO_PP:
        a.append(f"Conversão em 60 dias caiu {br(abs(delta))} p.p. em relação a {ant['mes']} "
                 f"({br(ant['conversao_60d_pct'])}% → {br(k['conversao_60d_pct'])}%).")
    media = k["conversao_60d_pct"]
    for o in d["origens"]:
        if o["leads"] >= ORIGEM_MIN_LEADS and o["conversao"] < media * ORIGEM_CONV_BAIXA:
            a.append(f"Origem \"{NOMES_ORIGEM.get(o['origem'], o['origem'])}\": {o['leads']} leads, mas conversão de "
                     f"só {br(o['conversao'])}% (média do mês: {br(media)}%).")
    sem = d["qualidade"]["sem_origem"]
    if sem and sem / k["leads"] > 0.10:
        a.append(f"{sem} leads ({100 * sem / k['leads']:.0f}%) chegaram sem origem identificada; "
                 "revisar o rastreamento das campanhas.")
    if d["qualidade"]["ciclo_negativo"]:
        a.append(f"{d['qualidade']['ciclo_negativo']} negócio(s) com data de ganho anterior ao primeiro contato "
                 "(excluído(s) do cálculo de ciclo).")
    return a


def br(v: float, casas: int = 1) -> str:
    """Formata número no padrão brasileiro (vírgula decimal)."""
    return f"{v:,.{casas}f}".replace(",", "X").replace(".", ",").replace("X", ".")


def seta(v: float | None, sufixo: str = "%", casas: int = 1) -> str:
    if v is None:
        return "—"
    return f"{'▲' if v > 0 else '▼' if v < 0 else '='} {br(abs(v), casas)}{sufixo}"


def markdown(d: dict) -> str:
    k, ant, g = d["kpi"], d["anterior"], d["ganhos"]
    al = alertas(d)
    linhas = [
        f"# Relatório mensal de KPIs comerciais — {d['mes']}",
        "",
        "> Gerado automaticamente por `src/report.py` a partir do modelo em SQL. "
        "Conversão medida em até 60 dias após o primeiro contato.",
        "",
        "## Resumo",
        "",
        "| Indicador | Mês | Mês anterior | Variação |",
        "|---|---:|---:|---:|",
        f"| Leads qualificados (MQL) | {br(k['leads'], 0)} | {br(ant['leads'], 0)} | {seta(k['leads_var_mes_pct'])} |",
        f"| Negócios em até 60 dias | {k['negocios_60d']} | {ant['negocios_60d']} | "
        f"{seta(k['negocios_60d'] - ant['negocios_60d'], '', 0)} |",
        f"| Conversão em 60 dias | {br(k['conversao_60d_pct'])}% | {br(ant['conversao_60d_pct'])}% | "
        f"{seta(k['conversao_var_pp'], ' p.p.')} |",
        f"| Negócios fechados no mês | {g['negocios']} | — | — |",
        f"| Ciclo médio dos negócios fechados | {g['ciclo']} dias | — | — |",
        "",
        "## Alertas",
        "",
        *([f"- ⚠️ {x}" for x in al] or ["- Nenhum alerta neste mês."]),
        "",
        "## Leads e conversão por origem",
        "",
        "| Origem | Leads | Negócios (60d) | Conversão |",
        "|---|---:|---:|---:|",
        *[f"| {NOMES_ORIGEM.get(o['origem'], o['origem'])} | {o['leads']} | {o['negocios']} | {br(o['conversao'])}% |"
          for o in d["origens"]],
        "",
        "## Negócios fechados no mês",
        "",
        "| Top SDRs | Negócios |  | Top segmentos | Negócios |",
        "|---|---:|---|---|---:|",
    ]
    for i in range(max(len(d["sdrs"]), len(d["segmentos"]))):
        s = d["sdrs"][i] if i < len(d["sdrs"]) else {"sdr_nome": "", "negocios": ""}
        t = d["segmentos"][i] if i < len(d["segmentos"]) else {"segmento": "", "negocios": ""}
        linhas.append(f"| {s['sdr_nome']} | {s['negocios']} |  | {t['segmento'].replace('_', ' ')} | {t['negocios']} |")
    return "\n".join(linhas) + "\n"


def html(todos: list[dict], panorama: dict) -> str:
    payload = json.dumps({"meses": [dict(d, alertas=alertas(d)) for d in todos], "panorama": panorama,
                          "nomes": NOMES_ORIGEM}, ensure_ascii=False)
    return (ROOT / "src" / "template.html").read_text(encoding="utf-8").replace("__DADOS__", payload)


def main() -> None:
    OUT_MD.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB)
    try:
        todos = [dados_mes(con, m) for m in MESES]
        panorama = {
            "mensal": q(con, "SELECT * FROM vw_kpi_mensal WHERE mes >= '2017-07'"),
            "origem": q(con, "SELECT * FROM vw_kpi_origem"),
            "ciclo": q(con, "SELECT * FROM vw_ciclo")[0],
            "ativacao": q(con, "SELECT * FROM vw_ativacao_sellers"),
            "sdr": q(con, "SELECT * FROM vw_kpi_sdr LIMIT 10"),
        }
    finally:
        con.close()
    for d in todos:
        (OUT_MD / f"{d['mes']}.md").write_text(markdown(d), encoding="utf-8")
    OUT_HTML.parent.mkdir(exist_ok=True)
    OUT_HTML.write_text(html(todos, panorama), encoding="utf-8")
    print(f"{len(todos)} relatórios em {OUT_MD.relative_to(ROOT)} e painel em {OUT_HTML.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
