import Foundation

public struct FeatureItem: Identifiable {
    public var id: String { name }
    public let name: String
    public let group: String
    public let mac: Bool
    public let detail: String
}

public enum FeatureCatalog {
    public static let source = "https://helpguide.sony.net/mdr/2984/v1/en/contents/TP1001856857.html"
    public static let items: [FeatureItem] = [
        .init(name: "Headset software updates", group: "System", mac: false, detail: "Install firmware with Sony Sound Connect on iPhone."),
        .init(name: "Voice guidance language", group: "System", mac: false, detail: "Set in Sony Sound Connect."),
        .init(name: "Voice guidance on/off", group: "System", mac: false, detail: "Set in Sony Sound Connect."),
        .init(name: "Voice guidance volume", group: "System", mac: false, detail: "Set in Sony Sound Connect."),
        .init(name: "Voice assistant", group: "System", mac: false, detail: "Phone integration; set in Sony Sound Connect."),
        .init(name: "Quick Access", group: "System", mac: false, detail: "Phone service integration; set in Sony Sound Connect."),
        .init(name: "Service Link", group: "System", mac: false, detail: "Phone service integration; set in Sony Sound Connect."),
        .init(name: "Touch sensor control panel", group: "System", mac: false, detail: "Write commands are not verified for this app; use Sony Sound Connect."),
        .init(name: "Bluetooth sound quality mode", group: "Connection", mac: false, detail: "Use Sony Sound Connect. This app does not install audio codecs."),
        .init(name: "Sidetone", group: "Sound", mac: false, detail: "Capture Voice During a Phone Call remains in Sony Sound Connect."),
        .init(name: "Turn off headset", group: "System", mac: false, detail: "Use the headphone power button or Sony Sound Connect."),
        .init(name: "Automatic power-off", group: "System", mac: true, detail: "When taken off / Never; requires a reported value."),
        .init(name: "Pause and resume when removed", group: "System", mac: true, detail: "Wearing detection toggle; confirmed by a device reply."),
        .init(name: "Connection status and settings", group: "Connection", mac: true, detail: "Separate Mac audio, Bluetooth link, control session, and playback-source status."),
        .init(name: "Two-device multipoint", group: "Connection", mac: false, detail: "Enable Connect to 2 devices simultaneously once in Sony Sound Connect. Connected-source switching is available on Mac."),
        .init(name: "LE Audio connection setting", group: "Connection", mac: false, detail: "Use Sony Sound Connect. This app controls the classic Bluetooth session."),
        .init(name: "Initialize headset", group: "System", mac: false, detail: "Factory reset remains in Sony Sound Connect or the hardware procedure."),
        .init(name: "Headset software version", group: "System", mac: true, detail: "Read-only firmware version, when reported."),
        .init(name: "Head gesture detection", group: "System", mac: false, detail: "Set in Sony Sound Connect."),
        .init(name: "LE Audio connection status", group: "Connection", mac: false, detail: "Check in Sony Sound Connect."),
        .init(name: "Bluetooth codec display", group: "Connection", mac: false, detail: "Check in Sony Sound Connect. No codec is inferred from device names."),
        .init(name: "DSEE Extreme setting display", group: "Sound", mac: true, detail: "Shows the reported Auto/Off setting; this does not prove processing is active during playback."),
        .init(name: "DSEE Extreme setting", group: "Sound", mac: true, detail: "Auto/Off; enabled only after the setting is reported."),
        .init(name: "Battery and charging", group: "System", mac: true, detail: "Reported battery percentage and charging status; cached values are labeled."),
        .init(name: "Equalizer presets for music/gaming", group: "Sound", mac: true, detail: "Off, Heavy, Clear, Hard, Soft. Other or game-specific presets stay in Sony’s app."),
        .init(name: "Custom equalizer editing", group: "Sound", mac: false, detail: "View the current curve on Mac; edit it in Sony Sound Connect until local hardware validation is complete."),
        .init(name: "Noise cancellation and ambient sound", group: "Sound", mac: true, detail: "NC / Ambient / Off, ambient level 0–20, and Focus on Voice."),
        .init(name: "NC/AMB button switching pattern", group: "System", mac: false, detail: "Set in Sony Sound Connect."),
        .init(name: "Auto ambient sound", group: "Sound", mac: false, detail: "Set in Sony Sound Connect."),
        .init(name: "Ambient detection sensitivity", group: "Sound", mac: false, detail: "Set in Sony Sound Connect."),
        .init(name: "Adaptive Sound Control", group: "Sound", mac: false, detail: "Phone behavior/location automation remains in Sony Sound Connect."),
        .init(name: "Speak-to-Chat", group: "Sound", mac: true, detail: "On/off, detection sensitivity, and resume timing."),
        .init(name: "Background music effects", group: "Sound", mac: true, detail: "Background Music mode and My Room / Living Room / Cafe."),
        .init(name: "Music and call volume", group: "Sound", mac: false, detail: "Use macOS volume keys, headphone gestures, or iPhone call-volume controls."),
        .init(name: "Play, pause, previous and next", group: "Sound", mac: false, detail: "Use your media app, Mac media keys, or headphone touch controls."),
        .init(name: "Easy pairing", group: "Connection", mac: false, detail: "Pair through macOS Bluetooth settings."),
        .init(name: "Voice Control language", group: "System", mac: false, detail: "Set in Sony Sound Connect."),
        .init(name: "Safe listening", group: "Sound", mac: false, detail: "Use Sony Sound Connect; this app does not measure listening exposure."),
        .init(name: "Spatial sound and head tracking", group: "Sound", mac: false, detail: "Configure compatible phone services in Sony Sound Connect."),
        .init(name: "Auto Play", group: "Sound", mac: false, detail: "Phone automation remains in Sony Sound Connect."),
        .init(name: "Auto Switch with speakers", group: "Connection", mac: false, detail: "Sony ecosystem integration remains in Sony Sound Connect."),
        .init(name: "360 Upmix for Cinema", group: "Sound", mac: true, detail: "Cinema listening mode; requires reported BGM and Cinema settings."),
        .init(name: "Call microphone mute", group: "Sound", mac: false, detail: "Use the phone or calling app’s mute control.")
    ]
}
