"""Liest die Hardware-Sensoren aus.

GPU (RTX 4090) über NVML (nvidia-ml-py) — die direkte Schnittstelle
zum NVIDIA-Treiber, dieselbe Datenquelle wie nvidia-smi. CPU und RAM
über psutil. Alles ohne Admin-Rechte.
"""
import winreg

import psutil
import pynvml

from models import SystemMetrics

_GB = 1024 ** 3


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

    def read(self) -> SystemMetrics:
        util = pynvml.nvmlDeviceGetUtilizationRates(self._gpu)
        mem = pynvml.nvmlDeviceGetMemoryInfo(self._gpu)
        temp = pynvml.nvmlDeviceGetTemperature(
            self._gpu, pynvml.NVML_TEMPERATURE_GPU
        )
        power = pynvml.nvmlDeviceGetPowerUsage(self._gpu) / 1000        # mW → W
        power_limit = pynvml.nvmlDeviceGetEnforcedPowerLimit(self._gpu) / 1000
        clock = pynvml.nvmlDeviceGetClockInfo(self._gpu, pynvml.NVML_CLOCK_GRAPHICS)
        mem_clock = pynvml.nvmlDeviceGetClockInfo(self._gpu, pynvml.NVML_CLOCK_MEM)
        try:
            fan = pynvml.nvmlDeviceGetFanSpeed(self._gpu)
        except pynvml.NVMLError:
            fan = 0  # z. B. bei Wasserkühlung oder im Zero-Fan-Modus

        per_core = psutil.cpu_percent(interval=None, percpu=True)
        freq = psutil.cpu_freq()
        ram = psutil.virtual_memory()

        return SystemMetrics(
            cpu_name=self._cpu_name,
            cpu_usage_percent=round(sum(per_core) / len(per_core), 1),
            cpu_per_core_percent=per_core,
            cpu_freq_mhz=freq.current if freq else 0.0,
            gpu_name=self._gpu_name,
            gpu_usage_percent=float(util.gpu),
            gpu_temp_celsius=float(temp),
            gpu_power_watts=round(power, 1),
            gpu_power_limit_watts=round(power_limit, 1),
            gpu_clock_mhz=float(clock),
            gpu_mem_clock_mhz=float(mem_clock),
            gpu_fan_percent=float(fan),
            vram_usage_gb=round(mem.used / _GB, 2),
            vram_total_gb=round(mem.total / _GB, 2),
            ram_usage_gb=round(ram.used / _GB, 2),
            ram_total_gb=round(ram.total / _GB, 2),
        )

    def close(self) -> None:
        pynvml.nvmlShutdown()
