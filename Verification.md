# XM6 Studio — verification report

Build: **1.0.1**, Apple Silicon, macOS 15+. Checked on **15 September 2026** using macOS **15.7.5**, Swift **6.1.2**, and actual **WH-1000XM6 firmware 3.1.5**.

## Version 1.0.1 branding update

Renamed the app to **XM6 Studio**. The Dock icon, sidebar brand mark, Overview image, About heading, menu-bar image and quick panel now use the actual Sony WH-1000XM6 product photograph. The image is bundled locally and attributed in THIRD_PARTY.md. The sidebar navigation uses standard system symbols, including the Headphones row. The Overview product photograph has a transparent background and sits directly on the card. The existing application identifier is retained so device choices and preferences carry over.

The headphone protocol and source-switching implementation are unchanged. Hardware results below were obtained with version 1.0.0; this branding update passed all 21 automated tests, asset and signature checks, and a native Overview visual check. The renamed app reopened and read firmware 3.1.5, battery 37%, both connected sources, and NC mode without changing headphone settings. Call, notification and sleep/wake checks remain pending.

## Result

The packaged app communicates with the user's headphones. **Ten alternating Mac/iPhone source switches were confirmed by headphone reports**, with both devices remaining listed as connected. Several sound and headphone settings were changed, confirmed, and restored. This verifies device-reported switching in this session; uninterrupted audible playback, incoming calls, notifications, and sleep/wake are not yet fully verified.

## Actual headphone checks

| Check | Result and scope |
| --- | --- |
| Model, firmware and battery | Passed: WH-1000XM6, firmware 3.1.5, live battery readings. Charging was not physically tested. |
| Connected sources | Passed: this Mac and iPhone identified; active source reported. No addresses or personal device names are included here. |
| Ten source switches | Passed: Mac → iPhone repeated five times. Each change confirmed from a headphone device-list report. Both remained connected. Finished on the initial iPhone source. |
| Mac audio routing | The Mac output was already WH-1000XM6. Each Mac action selected and read back that output successfully. A transition from another output was not separately tested. |
| Startup preservation | Read-only initialization verified by tests; repeated real app/control-session opens preserved the observed settings. No automatic setting writes or forced source switch on connect. |
| NC / Ambient / Off | Passed on modern noise-control subtype 0x19. NC → Ambient → Off → NC confirmed. Original NC mode restored. |
| Ambient level / voice focus | Passed: level 20 → 19 → 20; voice focus Off → On → Off. Original values restored. |
| Auto ambient settings | Preserved as reported when noise controls are changed. Editing these fields remains in Sony's app. |
| Background Music / Cinema | Passed: Standard → Background Music → Cinema → Standard. The reported Cafe room preference was preserved. Other room selections were not physically tested. |
| DSEE Extreme | Passed: Off → Auto → Off on a fresh attempt. An earlier attempt lost the control channel and correctly ended **unconfirmed**. Actual sound processing was not measured. |
| Speak-to-Chat | Passed: Off → On → Off; original setting restored. Voice sensitivity Auto → High → Auto confirmed. Resume timing remained Standard; other timing values were not physically tested. |
| Wearing detection | Passed: On → Off → On, confirmed and restored. Removing the headphones during playback was not tested. |
| Automatic power-off | Passed: When Taken Off → Never → When Taken Off, confirmed and restored. Waiting for actual power-off was not tested. |
| EQ | Current ten-band custom curve and preset code were read. Preset writes were not physically tested to preserve the user's custom EQ. Custom editing is unavailable. |
| Thirty-second idle release | Observed repeatedly. Cached values are labeled; Refresh opens controls and reads current settings again. |
| Control failure / recovery | Observed during the DSEE attempt: control-channel closure, bounded recovery, and an honest unconfirmed result. A later explicit attempt succeeded. The app does not close the Bluetooth audio connection. |
| Diagnostic export | Native save dialog and local redacted export checked. Reports separate control, audio-route, source, and Bluetooth events. |
| Interface | Overview, Sound and Headphones windows visually inspected in dark appearance; native accessibility controls exercised. Full VoiceOver, light appearance and menu-bar interaction have not been separately audited. |

## Automated checks

**21 tests passed** with Swift Testing. They cover known framing bytes, escaping, split frames, checksum corruption, malformed and truncated messages, bounded buffering, malformed-data corpus, distinct protocol tables, and diagnostic redaction/limits. Session tests cover read-only startup, required model identification, unavailable controls, state-based confirmation, ACKs that do not confirm a change, timeout and one recovery attempt, no replay of uncertain writes, confirmation after recovery, stale callbacks, idle release, source selection without device disconnects, and preservation of unexposed adaptive settings.

These simulated responses test app logic. They do not substitute for radio, call, or audible-playback testing.

## Remaining user checks

The following real-world checks remain pending. No confirmed outcome has been recorded for these scenarios yet.

1. **Call:** play audio on Mac, choose Listen on Mac, and receive an iPhone call. Confirm the call reaches the headphones, both sides can hear each other, and note whether Mac audio resumes after hanging up.
2. **Notification:** while Mac audio plays, trigger an ordinary iPhone notification. Note whether playback switches and whether it resumes. Sony firmware can still switch for phone sounds.
3. **Sleep/wake:** sleep and wake the Mac during normal use. Check audio reconnects, then Refresh controls. The app deliberately waits for your action to resume controls after wake.
4. **Sony Sound Connect coexistence:** choose Release controls for Sony app, open Sony's app on iPhone, change a harmless setting, close it, then Refresh on Mac. Check the new setting appears.
5. **Menu bar and appearance:** open the headphones icon beside the clock, check its quick controls, and confirm comfortable use in your usual light/dark appearance.

Full switching reliability is **pending these checks**. The app cannot prevent all firmware-driven interruptions while preserving multipoint and iPhone calls.

## Source and packaging

No runtime downloads or network services. Protocol dependencies are vendored at the pinned revisions recorded in THIRD_PARTY.md. The app is locally ad-hoc signed, not notarized for public distribution. Source and build scripts are supplied in **XM6 Studio Source.zip**.

Final package checks passed: strict code-signature verification, property-list validation, ARM64 executable identification, and integrity checks for both ZIP archives. After the final rebuild, macOS required refreshing this app's Bluetooth permission and relaunching. The final binary then read firmware 3.1.5, battery 41%, both connected sources, the original iPhone source, and restored NC mode successfully. The setup guide includes that recovery step.
