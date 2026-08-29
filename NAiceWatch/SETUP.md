# nAIce Apple Watch – Setup Guide

## Dateien erstellt (NAiceWatch/)

```
NAiceWatch/
├── NAiceWatchApp.swift          # Watch App Entry (SwiftUI)
├── Views/
│   ├── ContentView.swift        # 5-Tab Navigation
│   ├── BriefingView.swift       # WHOOP + Tages-Briefing
│   ├── MoodLogView.swift        # 1-Tap Stimmungs-Log
│   ├── HabitsView.swift         # Habit-Check & Quick-Log
│   ├── TasksView.swift          # Aufgaben anzeigen & abhaken
│   └── ChatView.swift           # Agent-Kurzchat (Sprache rein, Text raus)
├── Complication/
│   └── ComplicationController.swift  # WHOOP-Komplikation (6 Familien)
├── Connectivity/
│   └── WatchConnectivityManager.swift # iPhone <-> Watch Kommunikation
└── Resources/
    └── Info.plist               # Watch App Konfiguration
```

## iOS-Seite (bereits integriert ✅)

- `NAWatchConnectivityHandler.swift` – empfängt Watch-Nachrichten, liefert Daten
- `nAIceApp.swift` – initialisiert Handler beim App-Start

## So aktivierst du die Watch App in Xcode:

1. **Xcode öffnen** (ist schon offen: `HermesMobile.xcodeproj`)
2. **File → New → Target**
3. **watchOS → watchOS App** → Next
4. **Product Name:** `NAiceWatch`
5. **Bundle Identifier:** `pro.naice.app.watchkitapp`
6. **Team:** `GX89CS2T99`
7. **Language:** Swift
8. **Watch App with Complication:** ✅ ankreuzen
9. **Finish**

10. **Im neuen Watch Target:**
    - Lösche die Standard-Dateien (ContentView.swift etc.)
    - Ziehe alle Dateien aus `NAiceWatch/` in das Watch Target
    - **Wichtig:** Setze "Target Membership" auf das Watch Target (nicht iOS!)

11. **Build Settings des Watch Targets:**
    - `DEVELOPMENT_TEAM`: `GX89CS2T99`
    - `PRODUCT_BUNDLE_IDENTIFIER`: `pro.naice.app.watchkitapp`

12. **iOS Target → Build Phases:**
    - "+" → "Watch App" → NAiceWatch.app wählen
    - Dann wird die Watch App mit dem iOS Build mitgeliefert

13. **⌘B** – beide Targets bauen

14. **Auf iPhone installieren** (OTA) → Watch App wird automatisch übertragen

## Features der Watch App:

| Tab | Feature | Beschreibung |
|---|---|---|
| **1** ☀️ | Briefing | WHOOP Recovery, HRV, RHR, Schlaf, Tasks, Habits |
| **2** 😊 | Mood | 9 Stimmungen, 1 Tap speichern, Sync zum iPhone |
| **3** 🏃 | Habits | Heutige Habits checken, abhaken |
| **4** ✅ | Tasks | Aufgaben sehen, abhaken, Prio-Erkennung |
| **5** 🧠 | Agent | Kurzchat per Sprache, 4 Quick-Action-Buttons |

## Komplikationen (Zifferblatt):

| Familie | Anzeige |
|---|---|
| Circular Small | Recovery % + Ring |
| Graphic Circular | Heart-Icon + Gauge |
| Graphic Rectangular | "nAIce Recovery" + HRV/RHR + Schlaf |
| Graphic Corner | Recovery % + Label |
| Utilitarian Small | Recovery % + Ring |
| Graphic Extra Large | Recovery % + Gauge |