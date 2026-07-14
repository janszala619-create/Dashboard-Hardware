# PC Hardware Dashboard

Performance-Monitoring für RTX 4090 + Ryzen 7 7800X3D:
FastAPI-Server auf dem Windows-PC, SwiftUI-App auf dem iPhone (Polling im 1-Sekunden-Takt).

```
HardwareDashboard\
├── server\            Windows-Backend (Python/FastAPI)
│   ├── main.py        FastAPI-App, GET /api/stats
│   ├── sensors.py     SensorReader (NVML + psutil)
│   ├── models.py      Pydantic-Modelle (camelCase-JSON für Swift Codable)
│   └── requirements.txt
└── ios\PCMonitor\     SwiftUI-Dateien (MVVM) zum Einbinden in Xcode
    ├── PCMonitorApp.swift
    ├── Models\SensorData.swift
    ├── Services\MonitoringService.swift
    ├── ViewModels\DashboardViewModel.swift
    └── Views\DashboardView.swift
```

## 1. Windows-Server einrichten

Die venv mit allen Abhängigkeiten ist bereits angelegt (`server\.venv`).
Falls sie neu aufgesetzt werden muss:

```powershell
cd C:\Users\jansz\HardwareDashboard\server
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
```

**Server starten:**

```powershell
cd C:\Users\jansz\HardwareDashboard\server
.\.venv\Scripts\uvicorn main:app --host 0.0.0.0 --port 8000
```

`--host 0.0.0.0` ist nötig, damit das iPhone im WLAN zugreifen kann.
Beim ersten Start fragt die Windows-Firewall nach einer Freigabe — **„Zulassen"**
für private Netzwerke wählen. Alternativ manuell (als Admin):

```powershell
netsh advfirewall firewall add rule name="PC Hardware Monitor" dir=in action=allow protocol=TCP localport=8000 profile=private
```

**Test im Browser:** `http://localhost:8000/metrics` — liefert z. B.:

```json
{
  "timestamp": 1784037444.43,
  "cpu_usage_percent": 17.7,
  "gpu_usage_percent": 8.0,
  "gpu_temp_celsius": 36.0,
  "vram_usage_gb": 3.93,
  "vram_total_gb": 23.99
}
```

Interaktive API-Doku (Swagger): `http://localhost:8000/docs`

**IP-Adresse des PCs ermitteln** (kommt in die iOS-App):

```powershell
ipconfig
```

→ „IPv4-Adresse" des WLAN-/Ethernet-Adapters, z. B. `192.168.178.20`.
Tipp: Dem PC im Router eine feste IP zuweisen, sonst ändert sie sich gelegentlich.

## 2. iOS-App einrichten (auf dem Mac)

1. Xcode → **File → New → Project → iOS App**, Interface „SwiftUI",
   Name `PCMonitor`, Ziel iOS 17+.
2. Die von Xcode generierten Dateien `PCMonitorApp.swift`/`ContentView.swift`
   löschen und alle Dateien aus `ios\PCMonitor\` ins Projekt ziehen
   (Ordnerstruktur Models/Services/ViewModels/Views beibehalten).
3. In `DashboardViewModel.swift` die `host`-IP auf die Adresse des PCs setzen.
4. **Info.plist anpassen** — iOS blockiert unverschlüsseltes HTTP standardmäßig
   (App Transport Security). Zwei Einträge sind nötig:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
<key>NSLocalNetworkUsageDescription</key>
<string>Verbindet sich mit dem PC-Monitoring-Server im lokalen Netzwerk.</string>
</dict>
```

   (In Xcode: Target → Info → „App Transport Security Settings" →
   „Allows Local Networking" = YES, plus „Privacy – Local Network Usage
   Description".) Beim ersten Start fragt iOS einmalig nach der Erlaubnis
   für den Zugriff aufs lokale Netzwerk.

5. App auf dem iPhone (gleiches WLAN wie der PC!) starten.

## Architektur

**Backend:** `sensors.py` liest die GPU über NVML (`nvidia-ml-py`, die
direkte Treiber-Schnittstelle — dieselbe Datenquelle wie `nvidia-smi`)
und die CPU über `psutil` — beides ohne Admin-Rechte. `models.py`
definiert das Pydantic-Modell `SystemMetrics` mit snake_case-Feldern.
Die Route ist bewusst eine synchrone `def`-Funktion: FastAPI führt sie
im Threadpool aus, die blockierenden NVML-Aufrufe halten den Event-Loop
nicht auf.

**iOS:**
- `SystemMetrics.swift` — `Codable`-Struct, exaktes Gegenstück zum
  Pydantic-Modell; snake_case → camelCase übernimmt
  `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`
  (keine CodingKeys nötig). `Identifiable` über den Timestamp.
- `MetricsService` — `@MainActor ObservableObject` mit `@Published`
  Properties (`metrics`, `isConnected`, `errorMessage`); pollt per
  `URLSession` (`async/await`, 2-Sekunden-Timeout) im Sekundentakt und
  übersetzt `URLError`-Fälle in verständliche Fehlermeldungen. Die
  Poll-Schleife läuft in dem Task, den der `.task`-Modifier der View
  startet, und endet automatisch per Cancellation.
- `DashboardView` — `Gauge` für die GPU-Auslastung, Kacheln für
  GPU-Temp, CPU-Last und VRAM, Fehler-Banner und Online/Offline-Badge.

## IPA per GitHub Actions bauen (ohne Mac)

Der Workflow [.github/workflows/build-ios.yml](.github/workflows/build-ios.yml)
läuft bei jedem Push auf `main` (der `ios/**` berührt) sowie manuell über
den „Run workflow"-Button. Er generiert das Xcode-Projekt per XcodeGen aus
[ios/project.yml](ios/project.yml), baut die App **unsigniert** auf einem
macOS-Runner und lädt `PCMonitor.ipa` als Artefakt hoch.

**IPA aufs iPhone bringen:**

1. GitHub → Actions → letzter Lauf → Artefakt **PCMonitor-unsigniert** herunterladen.
2. Die `PCMonitor.ipa` mit [Sideloadly](https://sideloadly.io) (Windows) oder
   AltStore per Apple-ID signieren und aufs iPhone installieren.
   Mit kostenloser Apple-ID läuft die Signatur 7 Tage, dann neu signieren.

Hinweis: In privaten Repos verbrauchen macOS-Runner GitHub-Actions-Minuten
mit Faktor 10 (Free-Plan: 2000 Min/Monat ≈ 200 macOS-Minuten). In öffentlichen
Repos sind Actions kostenlos.

## Erweiterungsideen

- **CPU-Temperatur:** geht unter Windows nicht über psutil. Optionen:
  LibreHardwareMonitorLib per `pythonnet` einbinden (benötigt Admin-Rechte
  und derzeit Python ≤ 3.13) — oder LibreHardwareMonitor als Programm
  laufen lassen und dessen eingebauten Webserver (`http://localhost:8085/data.json`)
  vom FastAPI-Server mit abfragen.
- Weitere NVML-Werte: Leistungsaufnahme (`nvmlDeviceGetPowerUsage`),
  Taktraten (`nvmlDeviceGetClockInfo`), Lüfterdrehzahl (`nvmlDeviceGetFanSpeed`).
- Verlaufs-Charts in der App mit Swift Charts (`import Charts`).
- Autostart des Servers über die Windows-Aufgabenplanung.
