import Combine
import AVFoundation
import AudioToolbox
import CoreLocation
import Foundation
import UserNotifications

@MainActor
final class AppState: NSObject, ObservableObject {
    @Published var alarmSettings: AlarmSettings = Store.load("alarmSettings", fallback: .default) {
        didSet { Store.save(alarmSettings, key: "alarmSettings") }
    }
    @Published var weatherSettings: WeatherNotificationSettings = Store.load("weatherSettings", fallback: .default) {
        didSet { Store.save(weatherSettings, key: "weatherSettings") }
    }
    @Published var latestResult: WeatherAnalysisResult? = Store.loadOptional("latestWeatherResult") {
        didSet { Store.save(latestResult, key: "latestWeatherResult") }
    }
    @Published var isAlarmRinging = false
    @Published var statusMessage = ""
    @Published var activeTab = 0

    private let notificationCenter = UNUserNotificationCenter.current()
    private let locationManager = CLLocationManager()
    private let weatherClient = OpenMeteoClient()
    private let speech = AVSpeechSynthesizer()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        notificationCenter.delegate = self
    }

    func bootstrap() async {
        await requestNotificationAuthorization()
        if weatherSettings.useCurrentLocation {
            locationManager.requestWhenInUseAuthorization()
        }
        await scheduleAlarmIfNeeded()
    }

    func saveAlarm(hour: Int, minute: Int, enabled: Bool, snoozeMinutes: Int, sound: AlarmSound) async {
        alarmSettings.alarmTime.hour = hour
        alarmSettings.alarmTime.minute = minute
        alarmSettings.enabled = enabled
        alarmSettings.snoozeMinutes = snoozeMinutes
        alarmSettings.sound = sound
        await scheduleAlarmIfNeeded()
    }

    func scheduleAlarmIfNeeded() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily-alarm", "snooze-alarm"])
        guard alarmSettings.enabled else {
            statusMessage = "アラームはオフです。"
            return
        }

        registerAlarmNotificationCategory()
        let content = alarmNotificationContent()
        let trigger = UNCalendarNotificationTrigger(dateMatching: alarmSettings.alarmTime, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-alarm", content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            statusMessage = "次回アラームを登録しました。"
        } catch {
            statusMessage = "通知を登録できませんでした: \(error.localizedDescription)"
        }
    }

    func snoozeAlarm() async {
        isAlarmRinging = false
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["snooze-alarm"])
        registerAlarmNotificationCategory()

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(alarmSettings.snoozeMinutes, 1) * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "snooze-alarm", content: alarmNotificationContent(), trigger: trigger)

        do {
            try await notificationCenter.add(request)
            statusMessage = "\(alarmSettings.snoozeMinutes)分後にスヌーズします。"
        } catch {
            statusMessage = "スヌーズを登録できませんでした: \(error.localizedDescription)"
        }
    }

    func previewAlarmSound(_ sound: AlarmSound) {
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }

    func presentRingingAlarm() {
        isAlarmRinging = true
        activeTab = 0
        previewAlarmSound(alarmSettings.sound)
    }

    func stopAlarmAndFetchWeather() async {
        isAlarmRinging = false
        statusMessage = "天気を取得しています。"

        guard weatherSettings.weatherNotificationEnabled else {
            statusMessage = "天気通知はオフです。"
            return
        }

        let coordinate = await resolveCoordinate()
        guard let coordinate else {
            statusMessage = "位置情報を取得できません。手動地域を設定してください。"
            return
        }

        do {
            let forecasts = try await weatherClient.fetchHourlyForecast(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let result = WeatherAnalyzer.analyze(forecasts: forecasts, now: Date(), settings: weatherSettings)
            latestResult = result
            activeTab = 1
            statusMessage = "天気を更新しました。"
            speakIfNeeded(result.message)
        } catch {
            if var cached = latestResult {
                cached.isCachedFallback = true
                latestResult = cached
                activeTab = 1
                statusMessage = "天気取得に失敗したため前回結果を表示します。"
            } else {
                statusMessage = "天気情報を取得できませんでした: \(error.localizedDescription)"
            }
        }
    }

    func resolveCoordinate() async -> CLLocationCoordinate2D? {
        guard weatherSettings.useCurrentLocation else {
            return CLLocationCoordinate2D(
                latitude: weatherSettings.manualLocation.latitude,
                longitude: weatherSettings.manualLocation.longitude
            )
        }

        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return CLLocationCoordinate2D(
                latitude: weatherSettings.manualLocation.latitude,
                longitude: weatherSettings.manualLocation.longitude
            )
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func requestNotificationAuthorization() async {
        do {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            statusMessage = "通知権限を確認できませんでした。"
        }
    }

    private func alarmNotificationContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "アラーム"
        content.body = "停止すると今日の天気、傘、服装を確認します。"
        content.sound = .default
        content.categoryIdentifier = "ALARM_CATEGORY"
        return content
    }

    private func registerAlarmNotificationCategory() {
        let stop = UNNotificationAction(identifier: "STOP_ALARM", title: "停止して天気を見る", options: [.foreground])
        let snooze = UNNotificationAction(identifier: "SNOOZE_ALARM", title: "スヌーズ", options: [])
        let category = UNNotificationCategory(identifier: "ALARM_CATEGORY", actions: [stop, snooze], intentIdentifiers: [])
        notificationCenter.setNotificationCategories([category])
    }

    private func speakIfNeeded(_ text: String) {
        guard weatherSettings.voiceEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(utterance)
    }
}

extension AppState: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.last?.coordinate)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}

extension AppState: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            presentRingingAlarm()
        }
        return [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            presentRingingAlarm()
        }
        if response.actionIdentifier == "STOP_ALARM" {
            await stopAlarmAndFetchWeather()
        } else if response.actionIdentifier == "SNOOZE_ALARM" {
            await snoozeAlarm()
        }
    }
}
