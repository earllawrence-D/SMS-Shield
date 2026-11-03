# ShieldSMS

A thesis prototype Android app that detects smishing (SMS phishing) using a **hierarchical fuzzy inference system** with **lazy feature extraction** and **exact early exit**. It also filters calls from unknown numbers.

Built with Flutter (Dart) for the interface and algorithm, and Kotlin for Android-only services (SMS reception and call screening).

## Features

**SMS protection**
- Classifies each incoming SMS as *Normal*, *Suspicious* or *Highly Suspicious* from its content only. The sender ID is kept separate and is not part of the score.
- Messages at or above the blocking threshold go to the **Blocked** list. All others stay in the inbox.
- Default blocking threshold is *Highly Suspicious*. It can be changed to *Suspicious and above* in Settings.
- Blocked messages can be restored to the inbox with **Undo**.
- Each message has a details sheet showing the characteristic scores (C1–C7), subsystem outputs, score bounds, whether early exit happened, and a full-evaluation check.

**Call filtering**
- Calls from saved contacts ring normally.
- Calls from unsaved numbers are rejected when call rejection is on.
- **Repeated-call exception:** after three rejected calls from the same number within 20 minutes, the fourth call rings.
- Call filtering is independent of the SMS fuzzy score.

**Other**
- Local storage of messages, the blocked list, call log and settings.
- Runtime permission and role handling. If a permission is missing, the app explains the limit and takes no action.
- In-app simulators for incoming SMS and calls, so every flow can be tested without waiting for real traffic.

## How the detection works

Seven characteristics are scored from 0 to 1 and grouped into three fuzzy subsystems:

| Subsystem | Characteristics |
|---|---|
| Link | C1 Shortened URL, C2 Suspicious URL structure |
| Request | C3 Sensitive-information request, C4 Call to action, C5 Organization impersonation |
| Pressure | C6 Urgency / time limit, C7 Threat / reward lure |

1. Each subsystem is a zero-order TSK fuzzy system with three membership functions (Low, Medium, High) and a complete rule base (9, 27 and 9 rules). A final 27-rule system combines the three outputs into a risk score.
2. **Lazy extraction:** characteristics are only computed for a subsystem when it is reached.
3. **Exact early exit:** after each subsystem, the app computes the lowest and highest final score still possible. If both fall in the same risk class, it stops and skips the rest.
4. The hierarchical design uses 72 rules, versus 2,187 for a single flat seven-input system.

Every message is also evaluated in full as a reference, so the app can show that early exit matches full evaluation.

## Architecture

```
Application layer (Flutter UI)
   Home | Messages | Blocked | Protection | Settings
        |
SMS detection layer (Dart)               Call filtering layer (Kotlin)
   separate sender / content                check saved contacts
   lazy extraction C1-C7                    check rejection setting
   hierarchical fuzzy engine                repeated-call exception
   early-exit controller
   risk class + decision handler
        |                                        |
Android services (Kotlin, MethodChannel "shieldsms/native")
   SMS_RECEIVED receiver | CallScreeningService | contacts | permissions
        |
Local data storage
   SMS records and classifications | blocked list | call log | settings
```

Dart handles the interface and the fuzzy engine. Kotlin handles OS-level services, and the two communicate through a platform channel.

## Project structure

```
lib/
  main.dart       app shell and navigation
  engine.dart     fuzzy engine, early exit, verification
  state.dart      SMS flow, storage, native bridge
  screens.dart    all screens and the message details sheet
test/
  engine_test.dart
android/app/src/main/
  AndroidManifest.xml
  kotlin/com/example/shieldsms/
    MainActivity.kt                  MethodChannel handlers, role request
    SmsReceiver.kt                   queues incoming SMS
    CallRules.kt                     call filtering rules
    ShieldCallScreeningService.kt    real call screening
```

## Requirements

- Flutter SDK (Dart 3.3 or newer)
- Android SDK and JDK 17
- A physical Android device or emulator running **Android 10 (API 29) or newer**

iOS is not supported, because iOS does not allow apps to read or block SMS or screen calls.

## Run it

```
flutter pub get
flutter test
flutter run
```

Then open **Settings** in the app and grant:
- SMS permission
- Contacts permission
- Call-screening role

## Testing the flows

- **SMS:** on Home, use *Simulate incoming SMS*. Pick a sample (Smishing, Parcel, OTP, Personal) or type your own, then tap *Receive SMS*. Check the Blocked tab and tap a message for the breakdown.
- **Calls:** on Protection, use *Simulate incoming call*. Call an unsaved number four times to see three rejections followed by the exception. Use **+21 min** to move the clock past the 20-minute window.
- **Algorithm check:** in Settings, run the monotonicity and bounds test. `flutter test` covers the rule counts, monotonicity, bounds, and early-exit agreement.

## Known limitations

- Only the default SMS app on Android can hide or delete messages in the phone's inbox. This prototype quarantines messages inside the app and does not change the system inbox.
- Real incoming SMS are queued natively and classified when the app is opened or resumed, not while it is closed.
- The call simulator and real SMS reception only work on Android.
- The following are **placeholder values** and should be replaced with your frozen thesis values in `lib/engine.dart`: the thresholds `tau1` and `tau2`, the keyword cue lists, their weights and the maximum weights.
- The cue lists use simple keyword and pattern matching and have not been evaluated on a dataset.

## Thesis context

This is the prototype for a thesis on smishing detection with a hierarchical fuzzy inference algorithm. The flows follow the SMS blocking flowchart, the call-filtering flowchart and the system architecture described in Chapter 3.