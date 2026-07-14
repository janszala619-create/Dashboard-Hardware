"""Pydantic-Modell für die API-Antwort.

Die Feldnamen sind bewusst snake_case — die iOS-Seite mappt sie per
JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase auf camelCase.
"""
import time

from pydantic import BaseModel, Field


class SystemMetrics(BaseModel):
    timestamp: float = Field(default_factory=time.time)

    # CPU
    cpu_name: str
    cpu_usage_percent: float          # %
    cpu_per_core_percent: list[float] # % je logischem Kern
    cpu_freq_mhz: float               # aktueller Takt (Windows: oft Basistakt)

    # GPU
    gpu_name: str
    gpu_usage_percent: float          # %
    gpu_temp_celsius: float           # °C
    gpu_power_watts: float            # aktuelle Leistungsaufnahme
    gpu_power_limit_watts: float      # eingestelltes Power-Limit
    gpu_clock_mhz: float              # GPU-Kerntakt
    gpu_mem_clock_mhz: float          # Speichertakt
    gpu_fan_percent: float            # 0, falls nicht verfügbar

    # Speicher
    vram_usage_gb: float
    vram_total_gb: float
    ram_usage_gb: float
    ram_total_gb: float
