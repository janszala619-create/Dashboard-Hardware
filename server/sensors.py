"""Liest die Hardware-Sensoren aus.

GPU über NVML (nvidia-ml-py — dieselbe Datenquelle wie nvidia-smi),
CPU über psutil. Beides funktioniert ohne Admin-Rechte.
"""
import time
import winreg

import psutil
import pynvml

from models import CpuStats, GpuStats, SystemStats

_MB = 1024 * 1024


def _cpu_name() -> str:
    # Der Klarname (z. B. "AMD Ryzen 7 7800X3D 8-Core Processor")
    # steht unter Windows nur in der Registry.
    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"HARDWARE\DESCRIPTION\System\CentralProcessor\0",
        ) as key:
            return winreg.QueryValueEx(key, "ProcessorNameString")[0].strip()
    except OSError:
        return "CPU"


class SensorReader:
    def __init__(self) -> None:
        pynvml.nvmlInit()
        self._gpu = pynvml.nvmlDeviceGetHandleByIndex(0)
        name = pynvml.nvmlDeviceGetName(self._gpu)
        # Ältere nvidia-ml-py-Versionen liefern bytes statt str.
        self._gpu_name = name.decode() if isinstance(name, bytes) else name
        self._cpu_name = _cpu_name()
        # psutil misst relativ zum letzten Aufruf — einmal primen,
        # sonst liefert die erste echte Abfrage 0.0.
        psutil.cpu_percent(interval=None, percpu=True)

    def read(self) -> SystemStats:
        util = pynvml.nvmlDeviceGetUtilizationRates(self._gpu)
        mem = pynvml.nvmlDeviceGetMemoryInfo(self._gpu)
        temp = pynvml.nvmlDeviceGetTemperature(
            self._gpu, pynvml.NVML_TEMPERATURE_GPU
        )
        per_core = psutil.cpu_percent(interval=None, percpu=True)

        return SystemStats(
            timestamp=time.time(),
            gpu=GpuStats(
                name=self._gpu_name,
                load=float(util.gpu),
                temperature=float(temp),
                vram_used=mem.used // _MB,
                vram_total=mem.total // _MB,
            ),
            cpu=CpuStats(
                name=self._cpu_name,
                load=round(sum(per_core) / len(per_core), 1),
                per_core=per_core,
            ),
        )

    def close(self) -> None:
        pynvml.nvmlShutdown()
