# ShieldSMS (Flutter prototype)

Hierarchical fuzzy SMS-phishing detection (exact early exit + lazy extraction) with SMS blocking and call filtering.

## Setup (once)
```
flutter create --org com.example --project-name shieldsms .      # run inside this folder; keeps lib/, pubspec.yaml, test/
cp android_overlay/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
cp android_overlay/kotlin/*.kt android/app/src/main/kotlin/com/example/shieldsms/
```
Edit `android/app/build.gradle(.kts)`: set `minSdk = 29` (RoleManager call screening).
If you use another org/package, change the `package` line in the four .kt files.

```
flutter pub get
flutter test            # rule count 72/2187, monotonicity, bounds, early-exit == full
flutter run             # physical Android device
```
Then Settings -> grant SMS, READ_CONTACTS and the call-screening role.

## Layout
- `lib/engine.dart`  fuzzy engine (Algorithm 3.1). Placeholders to replace: `tau1/tau2`, cue lists/weights/max weights.
- `lib/state.dart`   SMS flow (Fig 3.10), persistence, native bridge.
- `lib/screens.dart` Home, Messages, Blocked, Protection, Settings, details sheet.
- `android_overlay/` SMS receiver, call-screening service, call rules (Fig 3.11).

## Android limits (document in Chapter 4)
- Only the default SMS app can hide/delete messages in the system inbox. This prototype quarantines inside the app and does not alter the system inbox.
- Incoming SMS are queued natively and classified when the app is opened/resumed.
- Call screening needs the Call Screening role.
