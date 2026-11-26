"""Testes de qualidade de dados e de consistência dos KPIs."""
import sqlite3
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
import build  # noqa: E402
import report  # noqa: E402


@pytest.fixture(scope="session")
def con(tmp_path_factory):
    db = build.construir(tmp_path_factory.mktemp("db") / "funil.db", exportar_pbi=False)
    c = sqlite3.connect(db)
    yield c
    c.close()


def um(con, sql):
    return con.execute(sql).fetchone()[0]


def test_carga_completa(con):
    assert um(con, "SELECT COUNT(*) FROM raw_mql") == 8000
    assert um(con, "SELECT COUNT(*) FROM raw_closed_deals") == 842


def test_um_lead_por_linha_na_fato(con):
    assert um(con, "SELECT COUNT(*) - COUNT(DISTINCT mql_id) FROM fct_leads") == 0


def test_todo_negocio_tem_lead_de_origem(con):
    assert um(con, """SELECT COUNT(*) FROM raw_closed_deals d
                      LEFT JOIN raw_mql m USING (mql_id) WHERE m.mql_id IS NULL""") == 0


def test_seller_unico_por_negocio(con):
    assert um(con, "SELECT COUNT(*) - COUNT(DISTINCT seller_id) FROM dim_seller") == 0


def test_ganho_60d_e_subconjunto_de_ganho(con):
    assert um(con, "SELECT COUNT(*) FROM fct_leads WHERE ganho_60d = 1 AND ganho = 0") == 0


def test_ciclo_negativo_sinalizado_e_excluido(con):
    assert um(con, "SELECT COUNT(*) FROM fct_leads WHERE ciclo_dias < 0 AND flag_ciclo_negativo = 0") == 0
    assert um(con, "SELECT COUNT(*) FROM fct_leads WHERE flag_ciclo_negativo = 1 AND ganho_60d = 1") == 0


def test_kpi_mensal_reconcilia_com_fato(con):
    assert um(con, "SELECT SUM(leads) FROM vw_kpi_mensal") == um(con, "SELECT COUNT(*) FROM fct_leads")
    assert um(con, "SELECT SUM(negocios_60d) FROM vw_kpi_mensal") == um(con, "SELECT SUM(ganho_60d) FROM fct_leads")


def test_vendas_respeitam_fim_da_base(con):
    assert um(con, "SELECT MAX(data_pedido) FROM stg_vendas") <= "2018-08-31"


def test_calendario_continuo(con):
    dias, ini, fim = con.execute("SELECT COUNT(*), MIN(data), MAX(data) FROM dim_calendario").fetchone()
    assert dias == um(con, f"SELECT CAST(julianday('{fim}') - julianday('{ini}') AS INTEGER) + 1")


def test_alerta_dispara_em_queda_de_conversao():
    d = {"kpi": {"conversao_60d_pct": 7.0, "leads": 100}, "anterior": {"conversao_60d_pct": 12.0, "mes": "2018-04"},
         "origens": [], "qualidade": {"sem_origem": 0, "ciclo_negativo": 0}}
    assert any("caiu" in a for a in report.alertas(d))


def test_sem_alerta_quando_tudo_normal():
    d = {"kpi": {"conversao_60d_pct": 12.0, "leads": 100}, "anterior": {"conversao_60d_pct": 11.0, "mes": "2018-04"},
         "origens": [{"origem": "organic_search", "leads": 60, "conversao": 11.0}],
         "qualidade": {"sem_origem": 5, "ciclo_negativo": 0}}
    assert report.alertas(d) == []
