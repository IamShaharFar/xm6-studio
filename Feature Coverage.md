# XM6 Studio — feature coverage

All 43 entries in [Sony’s WH-1000XM6 feature list](https://helpguide.sony.net/mdr/2984/v1/en/contents/TP1001856857.html) are mapped below. Checked 15 September 2026. The Mac app offers the explicitly listed controls; a row does not imply complete Sony-app parity.

**Hardware evidence** refers to actual WH-1000XM6 firmware 3.1.5 reports. Setting confirmation proves the device reported the value; it does not measure audible effects. See **Verification.md** for the full test record and pending call/notification checks.

| # | Sony feature | Where and extent | Hardware evidence |
| --- | --- | --- | --- |
| 1 | Headset software updates | Sony app / system: Install firmware with Sony Sound Connect on iPhone. | Outside the implemented Mac controls. |
| 2 | Voice guidance language | Sony app / system: Set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 3 | Voice guidance on/off | Sony app / system: Set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 4 | Voice guidance volume | Sony app / system: Set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 5 | Voice assistant | Sony app / system: Phone integration; set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 6 | Quick Access | Sony app / system: Phone service integration; set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 7 | Service Link | Sony app / system: Phone service integration; set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 8 | Touch sensor control panel | Sony app / system: Write commands are not verified for this app; use Sony Sound Connect. | Outside the implemented Mac controls. |
| 9 | Bluetooth sound quality mode | Sony app / system: Use Sony Sound Connect. This app does not install audio codecs. | Outside the implemented Mac controls. |
| 10 | Sidetone | Sony app / system: Capture Voice During a Phone Call remains in Sony Sound Connect. | Outside the implemented Mac controls. |
| 11 | Turn off headset | Sony app / system: Use the headphone power button or Sony Sound Connect. | Outside the implemented Mac controls. |
| 12 | Automatic power-off | Mac: When taken off / Never; requires a reported value. | Preference changed and restored; power-off timing not tested. |
| 13 | Pause and resume when removed | Mac: Wearing detection toggle; confirmed by a device reply. | Toggle changed and restored; physical removal not tested. |
| 14 | Connection status and settings | Mac: Separate Mac audio, Bluetooth link, control session, and playback-source status. | Read back on actual Mac/iPhone pair; ten source switches confirmed. |
| 15 | Two-device multipoint | Sony app / system: Enable Connect to 2 devices simultaneously once in Sony Sound Connect. Connected-source switching is available on Mac. | Both connected sources remained connected during ten switches; multipoint enable/disable is not changed. |
| 16 | LE Audio connection setting | Sony app / system: Use Sony Sound Connect. This app controls the classic Bluetooth session. | Outside the implemented Mac controls. |
| 17 | Initialize headset | Sony app / system: Factory reset remains in Sony Sound Connect or the hardware procedure. | Outside the implemented Mac controls. |
| 18 | Headset software version | Mac: Read-only firmware version, when reported. | Firmware 3.1.5 read. |
| 19 | Head gesture detection | Sony app / system: Set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 20 | LE Audio connection status | Sony app / system: Check in Sony Sound Connect. | Outside the implemented Mac controls. |
| 21 | Bluetooth codec display | Sony app / system: Check in Sony Sound Connect. No codec is inferred from device names. | Outside the implemented Mac controls. |
| 22 | DSEE Extreme setting display | Mac: Shows the reported Auto/Off setting; this does not prove processing is active during playback. | Off/Auto reports read; active processing not measured. |
| 23 | DSEE Extreme setting | Mac: Auto/Off; enabled only after the setting is reported. | Changed and restored; one earlier unconfirmed attempt recorded. |
| 24 | Battery and charging | Mac: Reported battery percentage and charging status; cached values are labeled. | Live percentage read; charging not tested. |
| 25 | Equalizer presets for music/gaming | Mac: Off, Heavy, Clear, Hard, Soft. Other or game-specific presets stay in Sony’s app. | Current custom curve read; preset writes not tested. |
| 26 | Custom equalizer editing | Sony app / system: View the current curve on Mac; edit it in Sony Sound Connect until local hardware validation is complete. | Current curve shown; editing disabled. |
| 27 | Noise cancellation and ambient sound | Mac: NC / Ambient / Off, ambient level 0–20, and Focus on Voice. | All three modes, ambient level and voice focus changed and restored. |
| 28 | NC/AMB button switching pattern | Sony app / system: Set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 29 | Auto ambient sound | Sony app / system: Set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 30 | Ambient detection sensitivity | Sony app / system: Set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 31 | Adaptive Sound Control | Sony app / system: Phone behavior/location automation remains in Sony Sound Connect. | Outside the implemented Mac controls. |
| 32 | Speak-to-Chat | Mac: On/off, detection sensitivity, and resume timing. | Toggle and sensitivity changed/restored; resume timing read only. |
| 33 | Background music effects | Mac: Background Music mode and My Room / Living Room / Cafe. | Mode changed/restored; Cafe room read, other rooms not tested. |
| 34 | Music and call volume | Sony app / system: Use macOS volume keys, headphone gestures, or iPhone call-volume controls. | Outside the implemented Mac controls. |
| 35 | Play, pause, previous and next | Sony app / system: Use your media app, Mac media keys, or headphone touch controls. | Outside the implemented Mac controls. |
| 36 | Easy pairing | Sony app / system: Pair through macOS Bluetooth settings. | Outside the implemented Mac controls. |
| 37 | Voice Control language | Sony app / system: Set in Sony Sound Connect. | Outside the implemented Mac controls. |
| 38 | Safe listening | Sony app / system: Use Sony Sound Connect; this app does not measure listening exposure. | Outside the implemented Mac controls. |
| 39 | Spatial sound and head tracking | Sony app / system: Configure compatible phone services in Sony Sound Connect. | Outside the implemented Mac controls. |
| 40 | Auto Play | Sony app / system: Phone automation remains in Sony Sound Connect. | Outside the implemented Mac controls. |
| 41 | Auto Switch with speakers | Sony app / system: Sony ecosystem integration remains in Sony Sound Connect. | Outside the implemented Mac controls. |
| 42 | 360 Upmix for Cinema | Mac: Cinema listening mode; requires reported BGM and Cinema settings. | Mode changed and restored. |
| 43 | Call microphone mute | Sony app / system: Use the phone or calling app’s mute control. | Outside the implemented Mac controls. |

## Mac-specific additions

- Separate Bluetooth, Mac audio-output, control-session and active-source indicators.
- Listen on Mac selects the Mac audio output and requests the headphone source; Listen on iPhone requests the connected iPhone source.
- Menu bar panel, native light/dark appearance, accessibility labels and keyboard shortcuts: ⌘R refresh; ⇧⌘R release controls; ⌘Q quit.
- Thirty-second idle control release, explicit release for Sony’s app, bounded recovery and redacted local diagnostics.
- Optional launch at login, off by default. No account or online service.

## Verification boundaries

Custom EQ writes are deliberately unavailable. All additional enabled writes require an identified WH-1000XM6 and a previously reported setting. Failed or unconfirmed commands display their outcome instead of success. Adaptive-ambient fields are preserved when changing noise control; phone-based automation remains in Sony’s app.
