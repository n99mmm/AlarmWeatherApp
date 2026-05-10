import Foundation


struct OpenMeteoClient {
    func fetchHourlyForecast(latitude: Double, longitude: Double) async throws -> [HourlyForecast] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,precipitation,weather_code"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return decoded.hourly.normalizedForecasts()
    }
}

private struct OpenMeteoResponse: Decodable {
    var hourly: Hourly

    struct Hourly: Decodable {
        var time: [String]
        var temperature2m: [Double]
        var precipitationProbability: [Double]
        var precipitation: [Double]
        var weatherCode: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case precipitationProbability = "precipitation_probability"
            case precipitation
            case weatherCode = "weather_code"
        }

        func normalizedForecasts() -> [HourlyForecast] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

            return time.indices.compactMap { index in
                guard
                    index < temperature2m.count,
                    index < precipitationProbability.count,
                    index < precipitation.count,
                    index < weatherCode.count,
                    let date = formatter.date(from: time[index])
                else { return nil }

                return HourlyForecast(
                    time: date,
                    precipitationProbability: precipitationProbability[index],
                    precipitationAmount: precipitation[index],
                    weather: WeatherKind(openMeteoCode: weatherCode[index]),
                    temperature: temperature2m[index]
                )
            }
        }
    }
}

private extension WeatherKind {
    init(openMeteoCode code: Int) {
        switch code {
        case 0:
            self = .clear
        case 1, 2, 3, 45, 48:
            self = .cloudy
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            self = .rain
        case 95, 96, 99:
            self = .thunderstorm
        case 71, 73, 75, 77, 85, 86:
            self = .snow
        default:
            self = .unknown
        }
    }
}
