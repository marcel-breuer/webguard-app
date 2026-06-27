# WebGuard for iOS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Native iPhone and iPad app for WebGuard monitoring alerts.

WebGuard brings your monitoring list and critical status changes directly to your Apple device. The app is intentionally focused: sign in, view monitorings, enable push notifications, and react quickly.

## What It Does

- Receive status changes immediately through Apple Push Notifications.
- Load monitorings from your WebGuard account.
- Review alerts, recoveries, and recent push events locally.
- Enable or disable push notifications per device.
- Avoid Firebase dependencies in the iOS app.
- Avoid paid third-party SDKs.
- Provide a native SwiftUI app for iPhone and iPad.

## Technology Stack

- SwiftUI
- Apple Push Notification service
- URLSession for the WebGuard API
- iOS Keychain for the mobile session
- UserDefaults for local monitoring and event caches
- Universal iOS target for iPhone and iPad

## Opening The Project

```text
ios/WebGuard.xcodeproj
```

In Xcode:

1. Select the `WebGuard` scheme.
2. Set the signing team.
3. Run the app on a real iPhone or iPad.

Non-secret build values are stored in:

```text
ios/WebGuard/Config/Debug.xcconfig
ios/WebGuard/Config/Release.xcconfig
```

Credentials do not belong in the repository. Backend URLs, team IDs, and the APNs environment may be stored in xcconfig files; passwords, APNs private keys, and test accounts should stay in local `.env` files or in the deployment environment.

The iOS app connects to `https://webguard.example.com`. The domain is configured through `WEBGUARD_BASE_URL` in the build configuration and cannot be edited in the app UI. The login screen only asks for email and password. New accounts are created from the app through the WebGuard registration page.

## Backend Requirements

The live API must provide these endpoints:

```text
POST /api/mobile/login
GET  /api/mobile/me
POST /api/mobile/logout
GET  /api/v1/monitorings
POST /api/v1/mobile-push-devices
PATCH /api/v1/mobile-push-devices/{id}
DELETE /api/v1/mobile-push-devices/{id}
```

APNs must be configured in the WebGuard Core deployment:

```env
APNS_KEY_ID=
APNS_TEAM_ID=
APNS_BUNDLE_ID=com.example.webguard
APNS_PRIVATE_KEY=
APNS_PRIVATE_KEY_PATH=
APNS_ENVIRONMENT=production
```

For local development builds installed directly from Xcode, `APNS_ENVIRONMENT=development` is relevant. For TestFlight and App Store builds, use `production`.

## MVP Flow

1. The user signs in with their WebGuard email and password.
2. The backend creates a mobile session.
3. The app stores the session in the iOS Keychain.
4. The app loads monitorings from `/api/v1/monitorings`.
5. The user enables push notifications.
6. The app registers the APNs device token with `push_provider = apns`.
7. WebGuard sends status changes directly through APNs.
8. On logout, the app revokes the device registration and mobile session.

## iPhone And iPad

The app is configured as a universal app:

- `TARGETED_DEVICE_FAMILY = 1,2`
- iPhone: portrait
- iPad: portrait and landscape
- Adaptive widths for login, monitorings, notifications, and settings
- Adaptive monitoring cards on larger displays

## App Store Preparation

See [docs/ios-app-store.md](docs/ios-app-store.md).

Summary:

1. Activate the Apple Developer Program.
2. Create the bundle ID `com.example.webguard` in Apple Developer.
3. Enable the Push Notifications capability.
4. Create an APNs auth key.
5. Configure the backend with the APNs values.
6. Create the App Store Connect app.
7. Build an archive in Xcode and upload it to App Store Connect.
8. Test through TestFlight first, then submit for App Review.

## App Store Copy

**Name**

```text
WebGuard
```

**Subtitle**

```text
Monitoring alerts for iPhone and iPad
```

**Short Description**

```text
Keep an eye on your WebGuard monitorings and receive critical status changes directly through push notifications.
```

**Description**

```text
WebGuard for iOS connects to your WebGuard account and shows your monitorings on iPhone and iPad.

Enable push notifications to receive critical incidents and recoveries directly on your device. The app is designed for quick assessment: monitoring list, status, recent push events, and device settings stay organized in one place.

Highlights:
- Sign in with your WebGuard account
- Monitoring list with status overview
- Push alerts for incidents and recoveries
- Recent notifications available locally
- Device-specific push settings
- Native iPhone and iPad app

WebGuard for iOS is the mobile companion for existing WebGuard accounts.
```

**Keywords**

```text
monitoring, uptime, alerts, status, incident, push, website, server, webguard
```

## App Privacy Notes For App Store Connect

The app does not use advertising or tracking.

Planned App Privacy disclosures:

- Contact info: email address for login
- Identifiers: user ID and device token for account and push mapping
- Usage data: monitoring and notification data within the account
- No data used for tracking

The privacy manifest file is stored at:

```text
ios/WebGuard/PrivacyInfo.xcprivacy
```

## Validation

Local build without code signing:

```sh
xcodebuild -project ios/WebGuard.xcodeproj -scheme WebGuard -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Live API smoke test:

```text
POST /api/mobile/login
GET /api/mobile/me
GET /api/v1/monitorings
POST /api/mobile/logout
```

## Contributing

Contributions are welcome. Please keep changes focused, tested, and easy to review.

1. Fork the repository.
2. Create a branch for your feature or bug fix.
3. Make the change and add tests for the behavior when applicable.
4. Run the relevant validation or test suite.
5. Commit with a descriptive Conventional Commits message.
6. Push the branch to your fork.
7. Open a pull request against the original repository's `main` branch.

Expectations:

- Write tests for new behavior and regressions when practical for the changed area.
- Keep existing validations passing.
- Prefer small pull requests with clear scope.
- Document user-facing behavior changes in the relevant docs file.

## License

WebGuard for iOS is open-source software licensed under the [MIT license](https://opensource.org/licenses/MIT).
