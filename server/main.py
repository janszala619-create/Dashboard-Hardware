"""FastAPI-Server für das PC-Hardware-Dashboard.

Start (im server\-Ordner, venv aktiviert):
    uvicorn main:app --host 0.0.0.0 --port 8000
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI

from models import SystemStats
from sensors import SensorReader

reader: SensorReader


@asynccontextmanager
async def lifespan(app: FastAPI):
    global reader
    reader = SensorReader()
    yield
    reader.close()


app = FastAPI(title="PC Hardware Monitor", version="1.0.0", lifespan=lifespan)


@app.get("/api/stats", response_model=SystemStats)
def get_stats() -> SystemStats:
    # Synchrone Route: FastAPI führt sie im Threadpool aus, die
    # blockierenden NVML-Aufrufe halten den Event-Loop nicht auf.
    return reader.read()
