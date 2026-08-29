import importlib

import pytest


@pytest.fixture()
def client(tmp_path, monkeypatch):
    # Fresh isolated sqlite file per test run -> tests are self-contained
    # and don't need a real Postgres instance, so `pytest` runs offline
    # and free in GitHub Actions.
    db_path = tmp_path / "test.db"
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{db_path}")

    import app as app_module
    importlib.reload(app_module)  # re-init engine against the fresh DB

    app_module.app.testing = True
    with app_module.app.test_client() as c:
        yield c


def test_index_returns_service_metadata(client):
    resp = client.get("/")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["service"] == "8byte-devops-assignment"


def test_health_reports_ok_when_db_reachable(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_create_task_requires_title(client):
    resp = client.post("/api/tasks", json={})
    assert resp.status_code == 400


def test_create_and_list_task_round_trip(client):
    create_resp = client.post("/api/tasks", json={"title": "write CHALLENGES.md"})
    assert create_resp.status_code == 201

    list_resp = client.get("/api/tasks")
    assert list_resp.status_code == 200
    titles = [t["title"] for t in list_resp.get_json()]
    assert "write CHALLENGES.md" in titles
