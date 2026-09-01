# Feature: News Card im Home-Tab "Meine Bereiche"

## Kontext & Ziel

nAIce kennt Johannes' Kontext (WHOOP, Deals, CRM, Kalender, Journal, Tech-Stack, Portfolio). Bisher fehlt: News-Filter.

Kein Feed-Scroll-Overkill. Der Home-Tab hat bereits die Sektion **"Meine Bereiche"** mit Cards (WHOOP, Deals, Tasks, etc.). Eine neue Card **"News"** kommt da rein und zeigt die wichtigsten Artikel auf einen Blick. Tappen öffnet den Full-Feed.

## Datenquelle / Backend

Amelia (Server 2) macht:
- RSS-Poller (alle 30 min): HN, TechCrunch, Ars, heise, Golem, X-Listen
- Relevanz-Filter via Agent: Artikel gegen Johannes' Kontext matchen (WHOOP, CRM, Kalender, Journal, Tech-Stack, Portfolio)
- Ergebnis: JSON unter `health.santoslab.de/api/news/feed`

**Endpoint:** `GET health.santoslab.de/api/news/feed`
**Response:**
```json
{
  "articles": [
    {
      "id": "uuid",
      "title": "SWS-Konkurrent raised $50M Series B",
      "source": "TechCrunch",
      "url": "https://...",
      "published_at": "2026-08-31T08:00:00Z",
      "relevance_tags": ["sws-deal", "logistics-ai"],
      "reason": "Betrifft aktiven Deal SWS Pilot (105k Pipeline)",
      "is_read": false,
      "is_saved": false,
      "preview": "Das Logistik-KI Startup OptiRoute bekommt Series B von a16z..."
    }
  ],
  "stats": {
    "filtered_today": 1805,
    "shown": 3,
    "updated_at": "2026-08-31T09:00:00Z"
  }
}
```

**Pull, nicht Push.** Die App fragt an beim Start + beim Sichtbarwerden des Home-Tabs + Pull-to-Refresh. Einfach HTTP-Call.

## UI – News Card in "Meine Bereiche"

### Card auf dem Home-Tab

Die Card passt sich ins bestehende "Meine Bereiche"-Raster ein. Gleiche Card-Höhe wie WHOOP/Deals.

**Compact State (Standard):**

```
┌────────────────────────────────────┐
│ 📰 News              [1.805 gefiltert] │
│                                       │
│ SWS-Konkurrent raised $50M Series B   │
│ Betrifft deinen aktiven SWS-Deal      │
│                                       │
│ [SWS-Deal] [Logistik-KI]     TechCrunch │
└────────────────────────────────────┘
```

- **Icon:** Newspaper oder SF Symbol
- **Title:** "News"
- **Badge:** "X gefiltert" als dezenter Counter (nicht als roter Badge)
- **Top-Artikel:** 1 Zeile Titel + 1 Zeile Grund ("Betrifft SWS-Deal")
- **Tags:** 1-2 kleine Chips (relevance_tags)
- **Source:** Rechts unten klein

**Wenn keine News:**
```
┌────────────────────────────────────┐
│ 📰 News              ✓ 0 relevant  │
│                                       │
│ Keine relevanten News heute.         │
│ 1.805 Stories gefiltert.             │
│                                       │
│ ┌────────────────────────┐           │
│ │   Pull to check again  │           │
│ └────────────────────────┘           │
└────────────────────────────────────┘
```

### Detail-View (beim Tappen auf die Card)

Tappen öffnet einen Push-Navigation-Screen mit der vollen Feed-Liste.

**Feed-Screen Layout:**

```
◀ Meine Bereiche           [Alle gelesen] [Lesezeichen]

┌─────────────────────────────────────────────┐
│ Heute: 1.805 gefiltert · 3 für dich         │
│                                             │
│ ── 31. August ───────────────────────────    │
│                                             │
│ ● TechCrunch  ·  2h ago                     │
│ SWS-Konkurrent raised $50M Series B          │
│ Das Logistik-KI Startup...                  │
│ [SWS-Deal] [Logistik]              [🔖]    │
│                                             │
│ ● Ars Technica  ·  5h ago                   │
│ Swift 6.2 Release Candidate veröffentlicht   │
│ Neue @MainActor Optimierungen...            │
│ [TechStack] [Swift]                 [🔖]    │
│                                             │
│ ── 30. August ─────────────────────────      │
│                                             │
│ ○ heise  ·  gestern                          │
│ Postgres 17: Wichtigste Neuerungen           │
│ [TechStack] [DB]                             │
└─────────────────────────────────────────────┘
```

Elemente pro Zeile:
1. **Read/Unread Dot:** ● = ungelesen, ○ = gelesen
2. **Source + relative Zeit**
3. **Titel:** Bold, max 2 Zeilen
4. **Preview:** 2 Zeilen
5. **Relevance-Chips:** Kleine Pillen
6. **Save-Button:** Lesezeichen

**Tap on Row:** Öffnet `SFSafariViewController`

### Section Header

"Gelesen & Gespeichert" als NavigationLink im Header. Zeigt alle is_read und is_saved Artikel.

### Stats-Bar unter dem Navigation-Title

"1.805 gefiltert · 3 für dich" als kleine Subtitle-Leiste. Signalisiert: "Der Twin arbeitet."

## Datenhaltung (lokal)

**SwiftData-Modell:**

```swift
@Model
class NewsArticle {
    var id: String
    var title: String
    var preview: String
    var source: String
    var url: String
    var publishedAt: Date
    var relevanceTags: [String]
    var reason: String
    var isRead: Bool
    var isSaved: Bool
    var fetchedAt: Date
}
```

- API-Response merged lokal
- Cache max 200 Artikel
- Nach 7 Tagen alte cleanen
- Card zeigt immer den aktuellsten ungelesenen Artikel

## Dark Mode

Card im bestehenden Dark Design. Schwarz. Relevance-Chips: Dunkelgrün #3D5A47. Source: Grau.

## Priority / Timing

**MVP:**
1. Card in "Meine Bereiche" mit Top-Artikel
2. Tap → Full Feed Screen
3. Safari öffnen beim Tappen auf Artikel
4. Read/Unread Tracking
5. Pull-to-Refresh

**V2:**
- Save/Lesezeichen
- Stats-Bar
- "Alle gelesen" Button
- Gelesen & Gespeichert Screen

## Erfolgskriterium

Johannes öffnet nAIce, sieht auf dem Home-Tab die News-Card, liest den Titel, tappt rein, sieht 2-3 relevante Artikel, liest einen in Safari. **Kein Badge. Keine 47 ungelesen. Kein Rauschen.**

---

**Backend-Lieferung:** Amelia liefert `GET health.santoslab.de/api/news/feed` mit Relevance-Filter.  
**iOS:** Jarvis baut Card + Feed-Screen + lokalen Cache.