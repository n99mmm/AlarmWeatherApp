import SwiftUI


struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.activeTab) {
            MainAlarmView()
                .tabItem { Label("アラーム", systemImage: "alarm") }
                .tag(0)

            WeatherResultView()
                .tabItem { Label("天気", systemImage: "cloud.rain") }
                .tag(1)

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(2)
        }
    }
}

struct MainAlarmView: View {
    @EnvironmentObject private var appState: AppState
    @State private var alarmDate = Date()
    @State private var enabled = false
    @State private var snoozeMinutes = 5
    @State private var alarmSound = AlarmSound.classic

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("アラーム時刻", selection: $alarmDate, displayedComponents: .hourAndMinute)
                    Toggle("アラーム", isOn: $enabled)
                    Stepper("スヌーズ \(snoozeMinutes)分", value: $snoozeMinutes, in: 1...30, step: 1)
                    Picker("アラーム音", selection: $alarmSound) {
                        ForEach(AlarmSound.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    Button {
                        appState.previewAlarmSound(alarmSound)
                    } label: {
                        Label("選択中の音を試聴", systemImage: "play.circle")
                    }
                    Button {
                        Task {
                            let components = Calendar.current.dateComponents([.hour, .minute], from: alarmDate)
                            await appState.saveAlarm(
                                hour: components.hour ?? 7,
                                minute: components.minute ?? 0,
                                enabled: enabled,
                                snoozeMinutes: snoozeMinutes,
                                sound: alarmSound
                            )
                        }
                    } label: {
                        Label("保存して通知を登録", systemImage: "checkmark.circle")
                    }
                }

                if appState.isAlarmRinging {
                    Section {
                        Button(role: .destructive) {
                            Task { await appState.stopAlarmAndFetchWeather() }
                        } label: {
                            Label("停止して天気を見る", systemImage: "stop.circle")
                        }
                        Button {
                            Task { await appState.snoozeAlarm() }
                        } label: {
                            Label("スヌーズ", systemImage: "zzz")
                        }
                    }
                }

                Section("現在の設定") {
                    LabeledContent("時刻", value: alarmTimeText(appState.alarmSettings.alarmTime))
                    LabeledContent("状態", value: appState.alarmSettings.enabled ? "オン" : "オフ")
                    LabeledContent("スヌーズ", value: "\(appState.alarmSettings.snoozeMinutes)分")
                    LabeledContent("アラーム音", value: appState.alarmSettings.sound.displayName)
                }

                if !appState.statusMessage.isEmpty {
                    Section {
                        Text(appState.statusMessage)
                    }
                }
            }
            .navigationTitle("朝のアラーム")
            .onAppear {
                alarmDate = dateFromComponents(appState.alarmSettings.alarmTime)
                enabled = appState.alarmSettings.enabled
                snoozeMinutes = appState.alarmSettings.snoozeMinutes
                alarmSound = appState.alarmSettings.sound
            }
        }
    }

    private func alarmTimeText(_ components: DateComponents) -> String {
        String(format: "%02d:%02d", components.hour ?? 7, components.minute ?? 0)
    }

    private func dateFromComponents(_ components: DateComponents) -> Date {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = components.hour ?? 7
        dateComponents.minute = components.minute ?? 0
        return Calendar.current.date(from: dateComponents) ?? Date()
    }
}

struct WeatherResultView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if let result = appState.latestResult {
                    List {
                        if result.isCachedFallback {
                            Section {
                                Text("天気取得に失敗したため、前回取得した情報を表示しています。")
                                    .foregroundStyle(.orange)
                            }
                        }

                        Section("通知文") {
                            Text(result.message)
                        }

                        Section("雨") {
                            LabeledContent("雨予報", value: result.hasRain ? "あり" : "なし")
                            if result.rainPeriods.isEmpty {
                                Text("今日これから雨の心配は少なそうです。")
                            } else {
                                ForEach(result.rainPeriods) { period in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("\(period.start)〜\(period.end)")
                                            .font(.headline)
                                        Text("最大降水確率 \(Int(period.maxProbability.rounded()))% / 最大降水量 \(period.maxPrecipitationAmount, specifier: "%.1f")mm")
                                    }
                                }
                            }
                        }

                        Section("傘") {
                            Text(result.umbrellaAdvice)
                        }

                        Section("気温と服装") {
                            LabeledContent("最低気温", value: "\(Int(result.temperatureSummary.minTemperature.rounded()))度")
                            LabeledContent("最高気温", value: "\(Int(result.temperatureSummary.maxTemperature.rounded()))度")
                            LabeledContent("気温差", value: "\(Int(result.temperatureSummary.temperatureDifference.rounded()))度")
                            Text(result.clothingAdvice)
                        }

                        Section("取得") {
                            LabeledContent("取得時刻", value: result.fetchedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                } else {
                    ContentUnavailableView("天気結果はまだありません", systemImage: "cloud.sun", description: Text("アラームを停止すると、天気、傘、服装の結果が表示されます。"))
                }
            }
            .navigationTitle("天気通知結果")
            .toolbar {
                Button {
                    Task { await appState.stopAlarmAndFetchWeather() }
                } label: {
                    Label("今すぐ取得", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var settings = WeatherNotificationSettings.default

    var body: some View {
        NavigationStack {
            Form {
                Section("通知") {
                    Toggle("天気通知", isOn: $settings.weatherNotificationEnabled)
                    Toggle("音声読み上げ", isOn: $settings.voiceEnabled)
                    Toggle("服装アドバイス", isOn: $settings.clothingAdviceEnabled)
                }

                Section("場所") {
                    Toggle("現在地を使う", isOn: $settings.useCurrentLocation)
                    TextField("地域名", text: $settings.manualLocation.name)
                    TextField("緯度", value: $settings.manualLocation.latitude, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("経度", value: $settings.manualLocation.longitude, format: .number)
                        .keyboardType(.decimalPad)
                }

                Section("判定しきい値") {
                    VStack(alignment: .leading) {
                        Text("降水確率 \(Int(settings.rainProbabilityThreshold))%")
                        Slider(value: $settings.rainProbabilityThreshold, in: 10...90, step: 5)
                    }
                    VStack(alignment: .leading) {
                        Text("強い雨 \(settings.strongRainAmountThreshold, specifier: "%.1f")mm")
                        Slider(value: $settings.strongRainAmountThreshold, in: 1...10, step: 0.5)
                    }
                    VStack(alignment: .leading) {
                        Text("気温差 \(Int(settings.temperatureDifferenceThreshold))度")
                        Slider(value: $settings.temperatureDifferenceThreshold, in: 5...12, step: 1)
                    }
                }

                Section {
                    Button {
                        appState.weatherSettings = settings
                    } label: {
                        Label("設定を保存", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("設定")
            .onAppear {
                settings = appState.weatherSettings
            }
        }
    }
}
