"""ELT do funil comercial: arquivos brutos -> SQLite (raw, staging, modelo estrela, KPIs)
e exportação das tabelas do modelo para o Power BI.

Uso:
    python src/build.py
"""
from __future__ import annotations

import csv
import gzip
import logging
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
DB = ROOT / "data" / "funil.db"
SQL = ROOT / "sql"
PBI = ROOT / "powerbi" / "dados"

FONTES = {
    "olist_marketing_qualified_leads_dataset.csv.gz": "raw_mql",
    "olist_closed_deals_dataset.csv.gz": "raw_closed_deals",
    "vendas_sellers_funil.csv.gz": "raw_vendas_sellers",
}

# tabelas do modelo estrela exportadas para o Power BI
EXPORTAR = ["dim_calendario", "dim_origem", "dim_sdr", "dim_sr", "dim_seller", "fct_leads", "fct_vendas_sellers"]

log = logging.getLogger("build")


def carregar(con: sqlite3.Connection, arquivo: Path, tabela: str) -> int:
    with gzip.open(arquivo, "rt", encoding="utf-8", newline="") as fh:
        r = csv.reader(fh)
        cab = [c.lstrip("﻿") for c in next(r)]
        sql = f"INSERT INTO {tabela} ({', '.join(cab)}) VALUES ({', '.join('?' * len(cab))})"
        cur = con.executemany(sql, ([v if v != "" else None for v in linha] for linha in r))
    return cur.rowcount


def exportar(con: sqlite3.Connection, destino: Path = PBI) -> None:
    destino.mkdir(parents=True, exist_ok=True)
    for t in EXPORTAR:
        cur = con.execute(f"SELECT * FROM {t}")
        with (destino / f"{t}.csv").open("w", encoding="utf-8", newline="") as fh:
            w = csv.writer(fh)
            w.writerow([c[0] for c in cur.description])
            w.writerows(cur)


def construir(db: Path = DB, exportar_pbi: bool = True) -> Path:
    db.unlink(missing_ok=True)
    con = sqlite3.connect(db)
    try:
        con.executescript((SQL / "01_raw.sql").read_text(encoding="utf-8"))
        for arq, tab in FONTES.items():
            log.info("%-20s %6d linhas", tab, carregar(con, RAW / arq, tab))
        con.commit()
        for f in ("02_staging.sql", "03_modelo_estrela.sql", "04_kpis.sql"):
            con.executescript((SQL / f).read_text(encoding="utf-8"))
        con.commit()
        if exportar_pbi:
            exportar(con)
            log.info("tabelas do modelo exportadas para %s", PBI.relative_to(ROOT))
    finally:
        con.close()
    return db


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    construir()
