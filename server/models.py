"""Pydantic-Modell für die API-Antwort.

Die Feldnamen sind bewusst snake_case — die iOS-Seite mappt sie per
JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase auf camelCase.
"""
import time

from pydantic import BaseModel, Field


class SystemMetrics(BaseModel):
    timestamp: float = Field(default_factory=time.time)
    cpu_usage_percent: float   # %
    gpu_usage_percent: float   # %
    gpu_temp_celsius: float    # °C
    vram_usage_gb: float       # GB
    vram_total_gb: float       # GB
