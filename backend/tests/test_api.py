def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"
    assert r.json()["fonte_dados"] == "sqlite_local"


def test_list_and_detail_are_treated(client):
    r = client.get("/proposicoes?tipo=PL&ano=2021")
    assert r.status_code == 200
    assert r.json()["items"][0]["status"]["rotulo"] == "Transformada em Norma"
    assert "uri_api" not in r.text
    r = client.get("/proposicoes/540979")
    assert r.status_code == 200
    assert r.json()["autores"][0]["nome"] == "Félix Mendonça Júnior"


def test_missing_proposition_returns_404(client):
    assert client.get("/proposicoes/999").status_code == 404
    assert client.get("/proposicoes/999/autores").status_code == 404
    assert client.get("/proposicoes/999/tramitacoes").status_code == 404
    assert client.get("/proposicoes/999/linha-do-tempo").status_code == 404


def test_history_and_timeline(client):
    assert len(client.get("/proposicoes/540979/tramitacoes").json()) == 1
    assert len(client.get("/proposicoes/540979/linha-do-tempo").json()) == 1


def test_favorites_are_idempotent_and_scoped(client):
    assert client.get("/favoritos").json()["meta"]["total"] == 0
    r = client.post("/favoritos", json={"proposicao_id": 540979})
    assert r.status_code == 201
    assert client.post("/favoritos", json={"proposicao_id": 540979}).status_code == 201
    assert client.get("/favoritos").json()["meta"]["total"] == 1
    assert client.delete("/favoritos/540979").status_code == 204
    assert client.delete("/favoritos/540979").status_code == 404


def test_zero_user_id_is_rejected_instead_of_using_default(client):
    response = client.get("/favoritos", headers={"X-User-Id": "0"})
    assert response.status_code == 400
    assert client.get("/favoritos", headers={"X-User-Id": "-1"}).status_code == 400
    assert client.get("/favoritos", headers={"X-User-Id": "999"}).status_code == 404


def test_verified_vigency_requires_admin_and_persists_official_evidence(
    client, monkeypatch
):
    from datetime import date, datetime, timezone
    import app.api.routes as routes

    def fake_verifier(**kwargs):
        assert kwargs["law_number"] == "14877/2024"
        return {
            "situacao_juridica": "VIGENTE",
            "lei_data_publicacao": date(2024, 6, 5),
            "lei_inicio_vigencia": date(2024, 6, 5),
            "fonte_url": "https://www.planalto.gov.br/lei.htm",
            "evidencia_texto": "Trecho oficial confirmado",
            "resposta_http": 200,
            "conteudo_sha256": "a" * 64,
            "verificada_em": datetime.now(timezone.utc),
        }

    monkeypatch.setattr(routes, "fetch_verified_evidence", fake_verifier)
    body = {
        "situacao_juridica": "VIGENTE",
        "fonte_url": "https://www2.camara.leg.br/norma.htm",
        "evidencia_texto": "Situação: Vigente no registro oficial da norma consultada",
        "revisor": "Revisão administrativa de teste",
        "lei_data_publicacao": "2024-06-05",
        "lei_inicio_vigencia": "2024-06-05",
    }
    assert client.post("/proposicoes/540979/verificar-vigencia", json=body).status_code == 403
    response = client.post(
        "/proposicoes/540979/verificar-vigencia",
        json=body,
        headers={"X-Admin-Token": "test-token"},
    )
    assert response.status_code == 201, response.text
    assert response.json()["resposta_http"] == 200
    detail = client.get("/proposicoes/540979").json()
    assert detail["status"]["codigo"] == "VIGENCIA_VERIFICADA"
    assert detail["status"]["fonte_vigencia"].endswith("lei.htm")


def test_search_validation_and_sync_guard(client):
    assert client.get("/proposicoes?ano=1800").status_code == 422
    assert (
        client.post("/etl/sincronizar", headers={"X-Admin-Token": "wrong"}).status_code
        == 403
    )
    assert (
        client.post(
            "/etl/sincronizar", headers={"X-Admin-Token": "test-token"}
        ).status_code
        == 202
    )


def test_etl_status_without_execution(client):
    response = client.get("/etl/status")
    assert response.status_code == 200
    assert response.json()["status"] == "SEM_EXECUCAO"


def test_presentation_labels_for_current_statuses():
    from app.services.presentation import STATUS_LABELS

    assert STATUS_LABELS["PRONTA_PARA_PAUTA"] == "Pronta para pauta"
    assert STATUS_LABELS["AGUARDANDO_SENADO"] == "Aguardando Senado"


def test_stale_legal_evidence_does_not_override_current_non_norm_status(client, monkeypatch):
    from datetime import date, datetime
    from types import SimpleNamespace
    import app.api.routes as routes

    project = SimpleNamespace(
        id_projeto=540979,
        status_interno="EM_TRAMITACAO",
        lei_numero="14877/2024",
        lei_tipo="Ordinária",
        lei_data_publicacao=date(2024, 6, 5),
        lei_inicio_vigencia=date(2024, 6, 5),
        situacao_juridica="VIGENTE",
        lei_fonte_publicacao="https://www2.camara.leg.br/norma.htm",
        fonte_vigencia="https://www2.camara.leg.br/norma.htm",
        vigencia_evidencia="Status oficial vigente previamente revisado",
        vigencia_verificada=True,
        vigencia_verificada_em=datetime(2026, 1, 1),
        ementa="Proposição de teste",
        sigla_tipo="PL",
        numero="2913",
        ano=2021,
        atualizado_em=None,
        data_apresentacao=None,
        autores=[],
    )
    monkeypatch.setattr(routes.repo, "get", lambda db, pid: project)
    monkeypatch.setattr(routes.repo, "tramitacoes", lambda db, pid: [])

    response = client.get("/proposicoes/540979")
    assert response.status_code == 200
    body = response.json()
    assert body["status"]["codigo"] == "EM_TRAMITACAO"
    assert body["status"]["vigencia_verificada"] is False
    assert body["lei_numero"] is None
    assert body["situacao_juridica"] is None
    assert body["fonte_vigencia"] is None


def test_list_can_filter_by_derived_verified_vigency_status(client):
    from app.db import SessionLocal
    from app.models import ProjetoLei

    with SessionLocal() as db:
        project = db.get(ProjetoLei, 540979)
        project.vigencia_verificada = True
        project.situacao_juridica = "VIGENTE"
        db.commit()

    response = client.get("/proposicoes?status=VIGENCIA_VERIFICADA")
    assert response.status_code == 200
    body = response.json()
    assert body["meta"]["total"] == 1
    assert body["items"][0]["status"]["codigo"] == "VIGENCIA_VERIFICADA"
