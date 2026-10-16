pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Weather from wttr.in's JSON: now, the details card and three days ahead.
// No key, and the place is guessed from the address unless the config names one.
// A failed fetch keeps the last good reading rather than showing an error.
Singleton {
    id: root

    property bool loaded: false
    property string condition: ""
    property int temp: 0
    property int feels: 0
    property int high: 0
    property int low: 0
    property int humidity: 0
    property int wind: 0
    property string windDir: ""
    property real windAngle: 0
    property int uv: 0
    property int pressure: 0
    property int visibility: 0
    property int code: 113
    property string place: ""
    property var days: []                  // [{ label, high, low, rain, code }]
    property var hours: []                 // [{ label, temp, rain, code }]
    property date updated: new Date()

    readonly property string icon: root.iconFor(root.code)

    // wttr.in's WWO codes to Material Symbols.
    function iconFor(code) {
        const c = Number(code);
        if (c === 113) return "sunny";
        if (c === 116) return "partly_cloudy_day";
        if (c === 119 || c === 122) return "cloud";
        if ([143, 248, 260].indexOf(c) >= 0) return "foggy";
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return "thunderstorm";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(c) >= 0) return "weather_snowy";
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) >= 0) return "weather_mix";
        return "rainy";
    }

    function refresh() { fetch.running = true; }

    Process {
        id: fetch
        command: ["curl", "-sS", "-m", "10", "https://wttr.in/" + encodeURIComponent(Demo.on ? Demo.place : Config.ready ? Config.options.weatherPlace : "") + "?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const now = d.current_condition[0];
                    root.condition = (now.weatherDesc && now.weatherDesc[0].value || "").trim();
                    root.temp = Number(now.temp_C);
                    root.feels = Number(now.FeelsLikeC);
                    root.humidity = Number(now.humidity);
                    root.wind = Number(now.windspeedKmph);
                    root.windDir = now.winddir16Point || "";
                    root.windAngle = Number(now.winddirDegree || 0);
                    root.uv = Number(now.uvIndex || 0);
                    root.pressure = Number(now.pressure || 0);
                    root.visibility = Number(now.visibility || 0);
                    root.code = Number(now.weatherCode || 113);
                    const area = d.nearest_area && d.nearest_area[0];
                    if (area) root.place = area.areaName[0].value + (area.country ? ", " + area.country[0].value : "");
                    const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                    root.days = (d.weather || []).map((w, i) => {
                        const dt = new Date(w.date + "T12:00:00");
                        const rain = Math.max.apply(null, w.hourly.map(h => Number(h.chanceofrain || 0)));
                        return {
                            label: i === 0 ? "Today" : names[dt.getDay()] + " " + dt.getDate(),
                            high: Number(w.maxtempC), low: Number(w.mintempC),
                            rain: rain, code: Number(w.hourly[4] ? w.hourly[4].weatherCode : 113)
                        };
                    });
                    if (root.days.length > 0) { root.high = root.days[0].high; root.low = root.days[0].low; }
                    const today = d.weather && d.weather[0] ? d.weather[0].hourly : [];
                    root.hours = today.map(h => ({
                        label: String(Math.floor(Number(h.time) / 100)).padStart(2, "0") + ":00",
                        temp: Number(h.tempC), rain: Number(h.chanceofrain || 0), code: Number(h.weatherCode)
                    }));
                    root.updated = new Date();
                    root.loaded = true;
                } catch (e) {
                    // keep the last good reading
                }
            }
        }
    }

    Timer {
        running: Config.ready
        repeat: true
        interval: 20 * 60 * 1000
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
