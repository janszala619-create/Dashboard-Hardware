"""Pydantic-Modelle für die API-Antworten.

Die Feldnamen werden als camelCase serialisiert, damit Swift sie
ohne Decoder-Konfiguration direkt per Codable einlesen kann.
"""
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class GpuStats(CamelModel):
    name: str
    load: float          # Auslastung in %
    temperature: float   # °C
    vram_used: int       # MB
    vram_total: int      # MB


class CpuStats(CamelModel):
    name: str
    load: float            # Gesamtauslastung in %
    per_core: list[float]  # Auslastung je logischem Kern in %


class SystemStats(CamelModel):
    timestamp: float
    gpu: GpuStats
    cpu: CpuStats
