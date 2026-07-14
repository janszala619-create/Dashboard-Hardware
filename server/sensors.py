"""Liest die Hardware-Sensoren aus.

GPU (RTX 4090) über NVML (nvidia-ml-py) — die direkte Schnittstelle
zum NVIDIA-Treiber, dieselbe Datenquelle wie nvidia-smi. CPU über
psutil. Beides funktioniert ohne Admin-Rechte.
"""
import psutil
import pynvml

from models import SystemMetrics

_GB = 1024 ** 3


class SensorReader:
    def __init__(self) -> None:
        pynvml.nvmlInit()
        self._gpu = pynvml.nvmlDeviceGetHandleByIndex(0)
        # psutil misst relativ zum letzten Aufruf — einmal primen,
        # sonst liefert die erste echte Abfrage 0.0.
        psutil.cpu_percent(interval=None)

    def read(self) -> SystemMetrics:
        util = pynvml.nvmlDeviceGetUtilizationRates(self._gpu)
        mem = pynvml.nvmlDeviceGetMemoryInfo(self._gpu)
        temp = pynvml.nvmlDeviceGetTemperature(
            self._gpu, pynvml.NVML_TEMPERATURE_GPU
        )

        return SystemMetrics(
            cpu_usage_percent=psutil.cpu_percent(interval=None),
            gpu_usage_percent=float(util.gpu),
            gpu_temp_celsius=float(temp),
            vram_usage_gb=round(mem.used / _GB, 2),
            vram_total_gb=round(mem.total / _GB, 2),
        )

    def close(self) -> None:
        pynvml.nvmlShutdown()
