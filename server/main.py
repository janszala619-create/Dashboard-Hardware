"""FastAPI-Server für das PC-Hardware-Dashboard.

Start (im server\-Ordner):
    .\\.venv\\Scripts\\uvicorn main:app --host 0.0.0.0 --port 8000
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI

from models import SystemMetrics
from sensors import SensorReader

reader: SensorReader


@asynccontextmanager
async def lifespan(app: FastAPI):
    global reader
    reader = SensorReader()
    yield
    reader.close()


app = FastAPI(title="PC Hardware Monitor", version="2.0.0", lifespan=lifespan)


@app.get("/metrics", response_model=SystemMetrics)
def get_metrics() -> SystemMetrics:
    # Synchrone Route: FastAPI führt sie im Threadpool aus, die
    # blockierenden NVML-Aufrufe halten den Event-Loop nicht auf.
    return reader.read()
