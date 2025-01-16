# simforge: Run iOS Apps on Apple Silicon Simulators

simforge is a tool that enables running ARM64 iOS apps on Apple Silicon iOS simulators by modifying the Mach-O binary headers to indicate simulator compatibility.

![simforge](./simforge.gif)

## Usage

### 1. Prepare the Decrypted App

Start with a decrypted build of the iOS app you want to run in the simulator.

### 2. Extract the IPA

Extract the `.app` bundle from the IPA:

```bash
unzip /path/to/your-app-decrypted.ipa -d /path/to/destination/
```

This will create a `Payload` directory containing the `.app` bundle.

### 3. Convert for Simulator

Run simforge on the extracted `.app` bundle:

```bash
simforge /path/to/Payload/YourApp.app
```

simforge will find all Mach-O binaries in the app bundle and modify their headers (in place) to indicate simulator compatibility

##### Example simforge Output

```bash
simforge ./app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app
Successfully converted: app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app/PlugIns/AWEVideoWidget.appex/AWEVideoWidget
Successfully converted: app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app/PlugIns/AwemeShareExtension.appex/AwemeShareExtension
Successfully converted: app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app/PlugIns/AwemeBroadcastExtension.appex/AwemeBroadcastExtension
Successfully converted: app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app/PlugIns/AwemeNotificationService.appex/AwemeNotificationService
Successfully converted: app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app/PlugIns/TikTokIntentExtension.appex/TikTokIntentExtension
Successfully converted: app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app/PlugIns/TikTokMessageExtension.appex/TikTokMessageExtension
Successfully converted: app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app/PlugIns/AwemeWidgetExtension.appex/AwemeWidgetExtension
Successfully converted: app-decrypt-com.zhiliaoapp.musically9bm7fcnv.app/TikTok
```

### 4. Code Sign the Modified App

After conversion, the app needs to be re-signed. Replace `$SIGNING_ID` with your developer certificate identifier:

```bash
# Sign frameworks first
codesign -f -s "$SIGNING_ID" /path/to/Payload/YourApp.app/Frameworks/*

# Then sign the main app bundle
codesign -f -s "$SIGNING_ID" /path/to/Payload/YourApp.app
```

To find your signing identity:
```bash
security find-identity -v -p codesigning
```

### 5. Install to Simulator

Install the modified and resigned app to a booted simulator:

```bash
# List available simulators
xcrun simctl list devices

# Install the app (replace UUID with your simulator's identifier)
xcrun simctl install "SIMULATOR_UUID" /path/to/Payload/YourApp.app
```
