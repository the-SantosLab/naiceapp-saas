# nAIce Pro — iOS App Spec

## Überblick
Eine native iOS App (iPad + iPhone) als internes Sales-Tool.
Name: **nAIce Pro** (oder **nAIce Outreach** — Johannes entscheidet)

## Backend API
Bereits fertig auf Server 2 unter http://76.13.150.247:8481/api/
- `/api/leads` — CRUD + Filter
- `/api/leads/{id}` — Detail mit Messages + Notes
- `/api/leads/{id}/outreach/generate` — AI-generierte Outreach-Nachricht
- `/api/leads/{id}/outreach/send` — Sendet Email via Amelia@thesantos.life (IONOS SMTP)
- `/api/leads/{id}/notes` — Notizen
- `/api/stats` — Dashboard-Kennzahlen
- `/api/pipeline` — Pipeline-Stages (new→contacted→replied→qualified→meeting→closed-won)

## iOS App Requirements

### Projekt-Basis
- Klone `~/Desktop/naiceapp-fresh/` (HermesMobile)
- Strippe alles ausser: Auth (API-Key aus Config), Networking (APIClient.swift, Endpoints.swift, APIError.swift, Config), Grundgerüst
- Neue Bundle-ID, neuer App-Name "nAIce Pro"
- Deployment Target: iOS 17+

### Screens

#### 1. Login / API-Config Screen
- Einmalig API-Server-URL + API-Key eingeben
- In Keychain speichern (NABiometricAuth nutzen)
- Health-Check auf /api/health

#### 2. Dashboard (Startseite)
Pipeline-Übersicht (Horizontal Bar Chart):
- new | contacted | replied | qualified | meeting | closed-won
- Jeweils Anzahl + farblich abgestuft
- KPIs darunter: Total Leads, Active, Conversion Rate
- By-Source Verteilung (Pie oder List)
- Top-5 Industries (Horizontal Bars)
- Quick-Action: "Neuer Lead"

#### 3. Lead-Liste (Main-Tab)
- Search Bar (nach Unternehmen, Branche, Kontakt)
- Filter-Buttons: Status, Industry, Source, Score
- Sort: Intent Score (default), Last Contacted, Company Name
- List Item: Company Name, Contact Name, Industry, Intent Score (visual badge), Last Status
- Swipe Actions: Contact (gehe zu Outreach), Add Note

#### 4. Lead Detail
- Header: Company, Website, Industry, Location
- Contact Section: Name, Titel, Email (tap→Mail), Phone (tap→Call), LinkedIn
- Intent Score: Editable Slider 0-100
- Tags (Chips)
- **Message History**: Chronologische Liste aller gesendeten/empfangenen Messages
  - Jede Message: Subject, Body (expandable/read more), Status (sent/replied/opened), Timestamp
  - Letzte farblich hervorgehoben
- **Activity Log / Notes**: Notizen + Automatische Updates
  - \+ Neue Note hinzufügen
- **Outreach Section** (CTTA Section):
  - "Generate Outreach" Button → lädt /api/leads/{id}/outreach/generate
  - Zeigt generierten Subject + Body in einer Preview
  - Editierbar (User soll Vorschlag anpassen können)
  - Tone Selector: professional | warm | direct
  - Context Hints: optionaler Text („erwähne unsere Case Study X")
  - "Send Email" Button → /api/leads/{id}/outreach/send
  - Confirmation Dialog

#### 5. Campaigns (optional - zweiter Tab)
- Liste aktiver Kampagnen
- Detail: Leads in Kampagne, gesendet/replied/converted

#### 6. Settings (Tab oder Modal)
- API-Server URL
- Push Notifications (Toggle, optional)
- Dark Mode Toggle
- About: Version, "Built by nAIce"

### Design
- Farbpalette: nAIce Brand (Gold #C8A951, Sand #F5E6CC, Dark #1A1A1A)
- iOS-native: SwiftUI (kein UIKit)
- Dark/Light Mode Support
- iPad: Split-View optimiert (Master-Detail)
- iPhone: NavigationStack (Push)
- Tab Bar mit 3 Tabs: Dashboard | Leads | Settings

### Swift / Models
```swift
struct Lead: Codable, Identifiable {
    let id: String
    var company: String
    var industry: String?
    var contactName: String?
    var contactEmail: String?
    var contactPhone: String?
    var contactLinkedin: String?
    var website: String?
    var intentScore: Int?
    var leadStatus: String
    var leadSource: String?
    var tags: [String]?
    var outreachCount: Int?
    var lastContacted: Date?
    var messageCount: Int?
    var latestMessage: String?
    var isActive: Bool
    let createdAt: Date?
}

struct LeadDetail: Codable {
    // same fields + messages + notes
}

struct OutboundMessage: Codable, Identifiable {
    let id: String
    var subject: String?
    var body: String
    var status: String
    var createdAt: Date?
    var replyReceived: Bool?
}

struct PipelineStats: Codable {
    var stages: [PipelineStage]
    var totalLeads: Int
    var conversionRate: Double
}

struct DashboardStats: Codable {
    var totalLeads: Int
    var activeLeads: Int
    var contacted: Int
    var replies: Int
    var meetings: Int
    var conversionRate: Double
    var bySource: [String: Int]
    var byIndustry: [String: Int]
}

struct GenerateResponse: Codable {
    var subject: String
    var body: String
    var personalizationNotes: String
}
```

### API Client Extension
- `GET /api/health`
- `GET /api/leads?status=&industry=&source=&search=&min_score=&active=&limit=&offset=`
- `GET /api/leads/{id}`
- `POST /api/leads`
- `PATCH /api/leads/{id}` (update status, score, note via "status" and "note")
- `POST /api/leads/{id}/notes`
- `POST /api/leads/{id}/outreach/generate` body: { lead_id, tone, context_hints? }
- `POST /api/leads/{id}/outreach/send` body: { lead_id, subject, body, channel }
- `GET /api/stats`
- `GET /api/pipeline`

### App Config
- API Base URL: `http://76.13.150.247:8481`
- Bundle: `com.naice.pro`
- App Name: `nAIce Pro`
- Optional: FaceID für zusätzliche Sicherheit

### Build & Deploy
- Dieser Spec liegt auf MacBook unter: `~/Desktop/naiceapp-fresh/naice-pro-spec.md`
- Jarvis: baue die App aus naiceapp-fresh
- TestFlight Enterprise Distribution
- Server-API ist live unter 76.13.150.247:8481

---

## Milestones
1. ✅ Backend API live (Port 8481, 5 Endpoint-Gruppen)
2. ⬜ iOS Projekt klonen + Tab-Struktur + Dashboard
3. ⬜ Lead-Liste + Detail + Outreach
4. ⬜ Testing + Deployment