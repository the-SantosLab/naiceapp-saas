import Foundation
import CoreLocation

// MARK: - Weather Models
struct NAWeather: Codable {
    let temperature: Double
    let feelsLike: Double
    let weatherCode: Int
    let windSpeed: Double
    let humidity: Double
    let locationName: String

    var condition: String {
        switch weatherCode {
        case 0: return "sonnig"
        case 1, 2, 3: return "bewolkt"
        case 45, 48: return "neblig"
        case 51, 53, 55: return "Nieselregen"
        case 56, 57: return "gefrierender Niesel"
        case 61, 63, 65: return "Regen"
        case 66, 67: return "gefrierender Regen"
        case 71, 73, 75: return "Schnee"
        case 77: return "Schneekörner"
        case 80, 81, 82: return "Regenschauer"
        case 85, 86: return "Schneeschauer"
        case 95: return "Gewitter"
        case 96, 99: return "Hagel"
        default: return "unbekannt"
        }
    }

    var iconName: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.hail.fill"
        default: return "questionmark"
        }
    }
}

// MARK: - Weather Service
@MainActor
class NAWeatherService: ObservableObject {
    static let shared = NAWeatherService()

    private let locationManager = CLLocationManager()
    @Published var weather: NAWeather?
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var locationAuthorized = false

    private init() {
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() async {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        locationAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
    }

    func fetchWeather() async {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            lastError = "Keine Standortberechtigung"
            return
        }

        isLoading = true
        lastError = nil

        guard let loc = locationManager.location else {
            lastError = "Standort nicht verfugbar"
            isLoading = false
            return
        }

        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude

        // Open-Meteo API (kostenlos, kein Key)
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true&hourly=temperature_2m,relative_humidity_2m,weather_code&timezone=auto&forecast_days=1"
        guard let url = URL(string: urlStr) else {
            lastError = "Ungultige URL"
            isLoading = false
            return
        }

        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                lastError = "Wetter-API Fehler"
                isLoading = false
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            if let current = json?["current_weather"] as? [String: Any],
               let temp = current["temperature"] as? Double,
               let code = current["weathercode"] as? Int,
               let wind = current["windspeed"] as? Double {

                var humidity: Double = 0
                if let hourly = json?["hourly"] as? [String: Any],
                   let humidities = hourly["relative_humidity_2m"] as? [Double],
                   let firstH = humidities.first {
                    humidity = firstH
                }

                // Reverse geocode for location name
                var locationName = "Dietmannsried"
                if let clLoc = locationManager.location {
                    let geocoder = CLGeocoder()
                    if let placemark = try? await geocoder.reverseGeocodeLocation(clLoc).first {
                        locationName = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Dietmannsried"
                    }
                }

                weather = NAWeather(
                    temperature: temp,
                    feelsLike: temp,
                    weatherCode: code,
                    windSpeed: wind,
                    humidity: humidity,
                    locationName: locationName
                )
            }
            isLoading = false
        } catch {
            lastError = error.localizedDescription
            isLoading = false
        }
    }
}