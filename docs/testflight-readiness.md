# TestFlight readiness checklist

Use this checklist to unblock the manual `ios-deploy` workflow for TestFlight uploads.

## Apple Developer and App Store Connect

1. Enroll in the Apple Developer Program and confirm the team has App Manager or Admin access in App Store Connect.
2. Register the app identifier `com.valuecompass.VCA` in Certificates, Identifiers & Profiles with Push Notifications enabled because the app declares the `remote-notification` background mode.
3. Create or reuse an Apple Distribution certificate for the team, export it as a password-protected `.p12`, and keep the password for GitHub Secrets.
4. Create an App Store provisioning profile for `com.valuecompass.VCA` using the distribution certificate, then download the `.mobileprovision`.
5. Create the App Store Connect app record for bundle ID `com.valuecompass.VCA`, SKU `value-compass-ios`, and the intended display name.
6. Create an App Store Connect API key with App Manager access and save the `.p8`, Key ID, and Issuer ID.
7. Add at least one internal tester group so uploaded builds can be assigned after processing.

## GitHub repository settings

Add these secrets under **Settings > Secrets and variables > Actions**:

| Secret | Value |
|---|---|
| `APPLE_DEV_CERTIFICATE` | Base64-encoded Apple Distribution `.p12`. |
| `APPLE_DEV_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12`. |
| `APPLE_PROVISIONING_PROFILE` | Base64-encoded App Store `.mobileprovision` for `com.valuecompass.VCA`. |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID. |
| `APP_STORE_CONNECT_API_KEY` | Base64-encoded App Store Connect API key `.p8`. |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID. |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID. |
| `API_BASE_URL` | Production API base URL used by the iOS app. |

Encoding command:

```sh
base64 -i path/to/file -o encoded.txt
```

## Release operation

1. Confirm `./frontend/build.sh` and `./frontend/run.sh` pass locally.
2. Open **Actions > ios-deploy > Run workflow**, set `ref` to the commit SHA, release branch, or tag to upload, then run the workflow.
3. After upload, wait for App Store Connect processing, assign the build to the internal tester group, and complete TestFlight compliance prompts if Apple requests them.
