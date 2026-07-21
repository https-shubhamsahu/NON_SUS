# Android Studio Project Sync and Maintenance Plan

Perform a comprehensive project sync, SDK verification, and upgrade analysis for the `android/` module while respecting established build-fix guardrails.

## User Review Required

> [!IMPORTANT]
> - The **AGP Upgrade Assistant** will be "simulated" via CLI diagnostics and package analysis, as I cannot directly interact with the IDE's modal GUI.
> - I will **decline** any automated suggestions from Android Studio to "modernize" the `subprojects {}` or `dependency {}` blocks in `build.gradle.kts` files, as these contain critical fixes for JVM target and Kotlin version mismatches.

## Proposed Changes

### [android]

#### [MODIFY] [gradle.properties](file:///C:/Users/shubh/_Active_Projects/NO_SUS/no_sus/android/gradle.properties)
Ensure `android.builtInKotlin=false` is maintained if any plugins are found to be incompatible with the new AGP 9.0+ built-in Kotlin mode.

### [pubspec.yaml]

#### [MODIFY] [pubspec.yaml](file:///C:/Users/shubh/_Active_Projects/NO_SUS/no_sus/pubspec.yaml)
Identify if upgrading `sentry_flutter`, `share_plus`, or `package_info_plus` resolves the Kotlin Gradle Plugin warnings.

## Verification Plan

### Automated Tests
1. **Gradle Sync**: Run `./gradlew help` to verify model stability.
2. **SDK Licenses**: Run `sdkmanager --licenses` to accept all pending license agreements.
3. **JDK Verification**: Verify `java -version` returns JDK 17.
4. **Signing Check**: Run `./gradlew :app:assembleRelease` to confirm that `key.properties` and the keystore are correctly picked up for a signed build.
5. **Outdated Packages**: Run `flutter pub outdated` to check for plugin updates targeting AGP 9 compatibility.

### Manual Verification
- Reporting back on which plugins are currently flagging KGP warnings and whether fixed versions exist on pub.dev.
