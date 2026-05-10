import Foundation

public enum WeatherAnalyzer {
    public static func forecastsUntilNight(_ forecasts: [HourlyForecast], now: Date, calendar: Calendar = .current) -> [HourlyForecast] {
        var endComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endComponents.hour = 23
        endComponents.minute = 59
        let endOfDay = calendar.date(from: endComponents) ?? now
        return forecasts
            .filter { $0.time >= now && $0.time <= endOfDay }
            .sorted { $0.time < $1.time }
    }

    public static func analyzeRainForecast(
        _ hourlyForecasts: [HourlyForecast],
        settings: WeatherNotificationSettings,
        calendar: Calendar = .current
    ) -> RainResult {
        let rainyHours = hourlyForecasts.filter { forecast in
            forecast.precipitationProbability >= settings.rainProbabilityThreshold ||
                forecast.precipitationAmount >= 0.1 ||
                [.rain, .shower, .thunderstorm].contains(forecast.weather)
        }.sorted { $0.time < $1.time }

        let periods = mergeContinuousHours(rainyHours, calendar: calendar)
        return RainResult(hasRain: !periods.isEmpty, rainPeriods: periods)
    }

    public static func analyzeUmbrellaAdvice(
        rainPeriods: [RainPeriod],
        settings: WeatherNotificationSettings
    ) -> String {
        guard !rainPeriods.isEmpty else {
            return "今日は傘はなくてもよさそうです。"
        }

        if rainPeriods.contains(where: { $0.weatherTypes.contains(.thunderstorm) }) {
            return "通常の傘を持ち、外出時は天候の急変に注意してください。"
        }

        if rainPeriods.contains(where: { $0.maxPrecipitationAmount >= settings.strongRainAmountThreshold }) {
            return "雨が強まる可能性があります。通常の傘を持ってください。"
        }

        return "雨に備えて折りたたみ傘があると安心です。"
    }

    public static func buildTemperatureSummary(
        _ hourlyForecasts: [HourlyForecast],
        now: Date
    ) -> TemperatureSummary {
        guard !hourlyForecasts.isEmpty else {
            return TemperatureSummary(minTemperature: 0, maxTemperature: 0, currentTemperature: 0, temperatureDifference: 0)
        }

        let temperatures = hourlyForecasts.map(\.temperature)
        let minTemperature = temperatures.min() ?? 0
        let maxTemperature = temperatures.max() ?? 0
        let nearest = hourlyForecasts.min {
            abs($0.time.timeIntervalSince(now)) < abs($1.time.timeIntervalSince(now))
        }

        return TemperatureSummary(
            minTemperature: minTemperature,
            maxTemperature: maxTemperature,
            currentTemperature: nearest?.temperature ?? minTemperature,
            temperatureDifference: maxTemperature - minTemperature
        )
    }

    public static func analyzeClothingByTemperature(
        _ summary: TemperatureSummary,
        settings: WeatherNotificationSettings
    ) -> String {
        let maxTemperature = summary.maxTemperature
        let minTemperature = summary.minTemperature
        let temperatureDifference = summary.temperatureDifference

        var advice: String

        if maxTemperature >= 30 {
            advice = "半袖や通気性のよい服がおすすめです。熱中症対策も意識してください。"
        } else if maxTemperature >= 25 {
            advice = "半袖や薄手の服で過ごしやすそうです。"
        } else if maxTemperature >= 20 {
            advice = "長袖シャツや薄手の羽織りがあると過ごしやすいです。"
        } else if maxTemperature >= 15 {
            advice = "長袖に薄手の上着がおすすめです。"
        } else if maxTemperature >= 10 {
            advice = "セーターやジャケット、軽めのコートがおすすめです。"
        } else if maxTemperature >= 5 {
            advice = "厚手のコートやマフラーがあると安心です。"
        } else {
            advice = "防寒着、手袋、マフラーなどでしっかり寒さ対策をしてください。"
        }

        if temperatureDifference >= 12 {
            advice += " 日中と朝晩の気温差が大きいので、時間帯に合わせて調整できる服装にしてください。"
        } else if temperatureDifference >= settings.temperatureDifferenceThreshold {
            advice += " 朝晩は冷えやすいので、脱ぎ着しやすい服装がおすすめです。"
        } else if temperatureDifference >= 5 {
            advice += " 朝晩に備えて軽い羽織りがあると安心です。"
        }

        if minTemperature < 0 {
            advice += " 最低気温が氷点下のため、足元の冷えや路面凍結にも注意してください。"
        } else if minTemperature < 5 {
            advice += " 朝晩はかなり冷えるため、防寒具を追加してください。"
        } else if minTemperature < 10 {
            advice += " 朝晩は冷えるため、上着を持つと安心です。"
        }

        return advice
    }

    public static func buildWeatherMessage(
        rainResult: RainResult,
        umbrellaAdvice: String,
        temperatureSummary: TemperatureSummary,
        clothingAdvice: String
    ) -> String {
        let min = Int(temperatureSummary.minTemperature.rounded())
        let max = Int(temperatureSummary.maxTemperature.rounded())
        let temperatureText = "気温は\(min)度〜\(max)度の予報です。"

        guard rainResult.hasRain, let firstRainPeriod = rainResult.rainPeriods.first else {
            return "今日は雨の心配は少なそうです。\(temperatureText)\(clothingAdvice)"
        }

        return "\(firstRainPeriod.start)〜\(firstRainPeriod.end)に雨が降る予報です。\(umbrellaAdvice)\(temperatureText)\(clothingAdvice)"
    }

    public static func analyze(
        forecasts: [HourlyForecast],
        now: Date,
        settings: WeatherNotificationSettings,
        calendar: Calendar = .current
    ) -> WeatherAnalysisResult {
        let targetForecasts = forecastsUntilNight(forecasts, now: now, calendar: calendar)
        let rainResult = analyzeRainForecast(targetForecasts, settings: settings, calendar: calendar)
        let umbrellaAdvice = analyzeUmbrellaAdvice(rainPeriods: rainResult.rainPeriods, settings: settings)
        let temperatureSummary = buildTemperatureSummary(targetForecasts, now: now)
        let clothingAdvice = settings.clothingAdviceEnabled
            ? analyzeClothingByTemperature(temperatureSummary, settings: settings)
            : "服装アドバイスはオフです。"
        let message = buildWeatherMessage(
            rainResult: rainResult,
            umbrellaAdvice: umbrellaAdvice,
            temperatureSummary: temperatureSummary,
            clothingAdvice: clothingAdvice
        )

        return WeatherAnalysisResult(
            hasRain: rainResult.hasRain,
            rainPeriods: rainResult.rainPeriods,
            umbrellaAdvice: umbrellaAdvice,
            temperatureSummary: temperatureSummary,
            clothingAdvice: clothingAdvice,
            message: message,
            fetchedAt: now
        )
    }

    private static func mergeContinuousHours(_ rainyHours: [HourlyForecast], calendar: Calendar) -> [RainPeriod] {
        guard !rainyHours.isEmpty else { return [] }

        var groups: [[HourlyForecast]] = []
        var currentGroup: [HourlyForecast] = [rainyHours[0]]

        for forecast in rainyHours.dropFirst() {
            let previous = currentGroup[currentGroup.count - 1]
            let minutes = calendar.dateComponents([.minute], from: previous.time, to: forecast.time).minute ?? 0
            if minutes <= 75 {
                currentGroup.append(forecast)
            } else {
                groups.append(currentGroup)
                currentGroup = [forecast]
            }
        }
        groups.append(currentGroup)

        return groups.map { group in
            let weatherTypes = Array(Set(group.map(\.weather))).sorted { $0.rawValue < $1.rawValue }
            let end = calendar.date(byAdding: .hour, value: 1, to: group[group.count - 1].time) ?? group[group.count - 1].time
            return RainPeriod(
                start: hourText(group[0].time, calendar: calendar),
                end: hourText(end, calendar: calendar),
                maxProbability: group.map(\.precipitationProbability).max() ?? 0,
                maxPrecipitationAmount: group.map(\.precipitationAmount).max() ?? 0,
                weatherTypes: weatherTypes
            )
        }
    }

    private static func hourText(_ date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        return "\(hour)時"
    }
}
