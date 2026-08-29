import os
import logging
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

# --- Logging: plain, structured-ish, goes to stdout so it lands in
# CloudWatch Logs via the container's log driver / CW agent (Part 3). ---
logging.basicConfig(
    level=logging.INFO,
    format='{"ts":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}',
)
log = logging.getLogger("8byte-app")

app = Flask(__name__)

# DATABASE_URL is injected as an env var at container runtime (from SSM
# Parameter Store on the EC2 host — see deploy step in cd.yml).
# Falls back to local sqlite so `pytest` / local `flask run` need zero setup.
DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///local.db")
engine = create_engine(DATABASE_URL, pool_pre_ping=True)


def init_db():
    with engine.begin() as conn:
        conn.execute(text(
            "CREATE TABLE IF NOT EXISTS tasks ("
            "id SERIAL PRIMARY KEY, "
            "title VARCHAR(255) NOT NULL, "
            "created_at TIMESTAMP NOT NULL"
            ")" if DATABASE_URL.startswith("postgresql") else
            "CREATE TABLE IF NOT EXISTS tasks ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "title VARCHAR(255) NOT NULL, "
            "created_at TIMESTAMP NOT NULL"
            ")"
        ))


try:
    init_db()
except OperationalError as exc:
    # Don't crash app startup if the DB isn't reachable yet (e.g. during
    # `docker build`'s layer caching or a brief RDS failover) — /health
    # will report DB status separately, and ALB health checks + the CI
    # tests don't require a live DB.
    log.warning("DB init deferred: %s", exc)


@app.get("/")
def index():
    return jsonify(
        service="8byte-devops-assignment",
        message="hello from Flask",
        time=datetime.now(timezone.utc).isoformat(),
    )


@app.get("/health")
def health():
    """Used by the ALB target group health check (Part 1) and can double
    as a liveness probe for any future ECS/EKS move."""
    db_ok = True
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except OperationalError:
        db_ok = False
    status = "ok" if db_ok else "degraded"
    code = 200 if db_ok else 503
    return jsonify(status=status, db=db_ok), code


@app.get("/api/tasks")
def list_tasks():
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT id, title, created_at FROM tasks ORDER BY id DESC")).fetchall()
    return jsonify([{"id": r[0], "title": r[1], "created_at": str(r[2])} for r in rows])


@app.post("/api/tasks")
def create_task():
    body = request.get_json(silent=True) or {}
    title = (body.get("title") or "").strip()
    if not title:
        return jsonify(error="title is required"), 400
    now = datetime.now(timezone.utc)
    with engine.begin() as conn:
        conn.execute(text("INSERT INTO tasks (title, created_at) VALUES (:t, :c)"), {"t": title, "c": now})
    log.info("task created: %s", title)
    return jsonify(title=title, created_at=now.isoformat()), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
