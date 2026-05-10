import Foundation

public enum WeatherKind: String, Codable, Sendable, Equatable, Hashable {
    case clear
    case cloudy
    case rain
    case shower
    case thunderstorm
    case snow
    case unknown
}

public struct AlarmSettings: Codable, Sendable, Equatable {
    public var alarmTime: DateComponents
    public var enabled: Bool
    public var snoozeMinutes: Int
    public var sound: AlarmSound

    public init(alarmTime: DateComponents, enabled: Bool, snoozeMinutes: Int, sound: AlarmSound) {
        self.alarmTime = alarmTime
        self.enabled = enabled
        self.snoozeMinutes = snoozeMinutes
        self.sound = sound
    }

    enum CodingKeys: String, CodingKey {
        case alarmTime
        case enabled
        case snoozeMinutes
        case sound
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alarmTime = try container.decode(DateComponents.self, forKey: .alarmTime)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        snoozeMinutes = try container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 5
        sound = try container.decodeIfPresent(AlarmSound.self, forKey: .sound) ?? .classic
    }

    public static let `default` = AlarmSettings(
        alarmTime: DateComponents(hour: 7, minute: 0),
        enabled: false,
        snoozeMinutes: 5,
        sound: .classic
    )
}

public enum AlarmSound: String, CaseIterable, Codable, Sendable, Equatable, Hashable, Identifiable {
    case classic
    case bell
    case chime
    case alert

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic:
            "クラシック"
        case .bell:
            "ベル"
        case .chime:
            "チャイム"
        case .alert:
            "アラート"
        }
    }

    public var systemSoundID: UInt32 {
        switch self {
        case .classic:
            1005
        case .bell:
            1013
        case .chime:
            1025
        case .alert:
            1006
        }
    }
}

public struct ManualLocation: Codable, Sendable, Equatable {
    public var name: String
    public var latitude: Double
    public var longitude: Double

    public init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    public static let tokyo = ManualLocation(name: "Tokyo", latitude: 35.6812, longitude: 139.7671)
}

public struct WeatherNotificationSettings: Codable, Sendable, Equatable {
    public var weatherNotificationEnabled: Bool
    public var useCurrentLocation: Bool
    public var manualLocation: ManualLocation
    public var voiceEnabled: Bool
    public var rainProbabilityThreshold: Double
    public var strongRainAmountThreshold: Double
    public var clothingAdviceEnabled: Bool
    public var temperatureDifferenceThreshold: Double

    public init(
        weatherNotificationEnabled: Bool,
        useCurrentLocation: Bool,
        manualLocation: ManualLocation,
        voiceEnabled: Bool,
        rainProbabilityThreshold: Double,
        strongRainAmountThreshold: Double,
        clothingAdviceEnabled: Bool,
        temperatureDifferenceThreshold: Double
    ) {
        self.weatherNotificationEnabled = weatherNotificationEnabled
        self.useCurrentLocation = useCurrentLocation
        self.manualLocation = manualLocation
        self.voiceEnabled = voiceEnabled
        self.rainProbabilityThreshold = rainProbabilityThreshold
        self.strongRainAmountThreshold = strongRainAmountThreshold
        self.clothingAdviceEnabled = clothingAdviceEnabled
        self.temperatureDifferenceThreshold = temperatureDifferenceThreshold
    }

    public static let `default` = WeatherNotificationSettings(
        weatherNotificationEnabled: true,
        useCurrentLocation: true,
        manualLocation: .tokyo,
        voiceEnabled: true,
        rainProbabilityThreshold: 40,
        strongRainAmountThreshold: 3.0,
        clothingAdviceEnabled: true,
        temperatureDifferenceThreshold: 8
    )
}

public struct HourlyForecast: Codable, Sendable, Equatable {
    public var time: Date
    public var precipitationProbability: Double
    public var precipitationAmount: Double
    public var weather: WeatherKind
    public var temperature: Double

    public init(
        time: Date,
        precipitationProbability: Double,
        precipitationAmount: Double,
        weather: WeatherKind,
        temperature: Double
    ) {
        self.time = time
        self.precipitationProbability = precipitationProbability
        self.precipitationAmount = precipitationAmount
        self.weather = weather
        self.temperature = temperature
    }
}

public struct RainPeriod: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(start)-\(end)-\(maxProbability)-\(maxPrecipitationAmount)" }
    public var start: String
    public var end: String
    public var maxProbability: Double
    public var maxPrecipitationAmount: Double
    public var weatherTypes: [WeatherKind]

    public init(
        start: String,
        end: String,
        maxProbability: Double,
        maxPrecipitationAmount: Double,
        weatherTypes: [WeatherKind]
    ) {
        self.start = start
        self.end = end
        self.maxProbability = maxProbability
        self.maxPrecipitationAmount = maxPrecipitationAmount
        self.weatherTypes = weatherTypes
    }
}

public struct RainResult: Codable, Sendable, Equatable {
    public var hasRain: Bool
    public var rainPeriods: [RainPeriod]

    public init(hasRain: Bool, rainPeriods: [RainPeriod]) {
        self.hasRain = hasRain
        self.rainPeriods = rainPeriods
    }
}

public struct TemperatureSummary: Codable, Sendable, Equatable {
    public var minTemperature: Double
    public var maxTemperature: Double
    public var currentTemperature: Double
    public var temperatureDifference: Double

    public init(minTemperature: Double, maxTemperature: Double, currentTemperature: Double, temperatureDifference: Double) {
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
        self.currentTemperature = currentTemperature
        self.temperatureDifference = temperatureDifference
    }
}

public struct WeatherAnalysisResult: Codable, Sendable, Equatable {
    public var hasRain: Bool
    public var rainPeriods: [RainPeriod]
    public var umbrellaAdvice: String
    public var temperatureSummary: TemperatureSummary
    public var clothingAdvice: String
    public var message: String
    public var fetchedAt: Date
    public var isCachedFallback: Bool

    public init(
        hasRain: Bool,
        rainPeriods: [RainPeriod],
        umbrellaAdvice: String,
        temperatureSummary: TemperatureSummary,
        clothingAdvice: String,
        message: String,
        fetchedAt: Date,
        isCachedFallback: Bool = false
    ) {
        self.hasRain = hasRain
        self.rainPeriods = rainPeriods
        self.umbrellaAdvice = umbrellaAdvice
        self.temperatureSummary = temperatureSummary
        self.clothingAdvice = clothingAdvice
        self.message = message
        self.fetchedAt = fetchedAt
        self.isCachedFallback = isCachedFallback
    }
}
