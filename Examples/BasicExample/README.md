# BasicExample - LinkForty iOS SDK

A simple SwiftUI app demonstrating all features of the LinkForty iOS SDK.

## Features Demonstrated

- ✅ SDK initialization with configuration
- ✅ Install attribution tracking
- ✅ Deferred deep link handling (install attribution)
- ✅ Direct deep link handling (Universal Links)
- ✅ Event tracking
- ✅ Revenue tracking
- ✅ Screen-view tracking (`trackScreenView` + the SwiftUI `.linkfortyScreen` modifier)
- ✅ Last-click attribution (events automatically credited to the deep link that opened the app)
- ✅ Event queue management
- ✅ Programmatic link creation
- ✅ Data management (clear/reset)

## Running the Example

### Prerequisites

1. **LinkForty Backend**: the hosted service (`https://api.linkforty.com`) or your own self-hosted Core server
2. **App Token**: on the hosted service, your workspace's app token (`at_…`), from the dashboard. A self-hosted Core server doesn't need one.
3. **API Key** (optional): only for the "Create Short Link" button (`createLink`). It is a secret, so leave it out unless you try link creation.

### Setup

1. The example is the two Swift files in this folder, with no Xcode project. Create a new iOS App project in Xcode (SwiftUI interface, iOS 16 or later deployment target, the SDK's minimum), add this package (File > Add Package Dependencies, `https://github.com/LinkForty/mobile-sdk-ios`), and replace the generated app and content view files with `BasicExampleApp.swift` and `ContentView.swift`.

2. Update the configuration in `BasicExampleApp.swift`:
   ```swift
   let config = LinkFortyConfig(
       baseURL: URL(string: "https://api.linkforty.com")!, // or your own server
       apiKey: nil,                    // only for createLink(); a secret
       appToken: "at_your_app_token",  // required on the hosted service
       debug: true
   )
   ```

3. For Universal Links (optional):
   - Enable the "Associated Domains" capability
   - Add one entry per host your links are served on: `applinks:go.yourdomain.com` (the link domain in your short links, not the API `baseURL`)
   - Ensure that host serves the AASA file

4. Run the app on a device or simulator

### Testing Attribution

#### Test Deferred Deep Linking (Install Attribution)

1. Create a short link in your LinkForty dashboard
2. Open the link in Safari on your device
3. If the app is not installed, install it from Xcode
4. On first launch, the deferred deep link callback will fire
5. Check the "Deep Link Data" section in the app

#### Test Direct Deep Links

1. With the app installed, create a short link
2. Open the link in Safari
3. The app should open automatically
4. Check the "Deep Link Data" section for the parsed data

### Test Link Creation

1. Tap "Create Short Link" in the Link Creation section
2. The created URL and short code will appear below the button
3. Share the URL or open it in Safari to test the deep link flow

### Testing Events

Use the buttons in the app to:
- Track button clicks
- Track page views
- Track a screen view (the root view also reports a `Home` screen view on appear via `.linkfortyScreen`)
- Track revenue
- Flush the event queue
- Clear all data

Monitor the Xcode console for SDK logs (when `debug: true`).

## Code Structure

```
BasicExample/
├── BasicExampleApp.swift    # Main app entry point & SDK initialization
├── ContentView.swift         # Main UI with all SDK features
└── README.md                # This file
```

### Key Components

**BasicExampleApp.swift**
- Initializes the SDK on app launch
- Registers deep link callbacks
- Contains `AppState` for managing SDK state

**ContentView.swift**
- Displays SDK status and attribution info
- Provides buttons for testing all SDK features
- Shows deep link data when received

## Troubleshooting

### SDK Not Initializing

- Check that your `baseURL` is correct
- On the hosted service, verify your `appToken`
- Ensure your backend is running and accessible
- Check Xcode console for error messages

### Deep Links Not Working

- Verify Associated Domains are configured
- Check AASA file is served at `https://yourdomain.com/.well-known/apple-app-site-association`
- Test AASA file with Apple's validator: https://search.developer.apple.com/appsearch-validation-tool
- Ensure app is installed via Xcode or TestFlight (not debug builds for production links)

### Events Not Tracking

- Verify SDK is initialized (`isInitialized == true`)
- Check that `installId` is present
- Look for error messages in console
- Try flushing the event queue manually

## Additional Resources

- [Main SDK Documentation](../../README.md)
- [LinkForty Core](https://github.com/linkforty/core)

## Support

For issues or questions:
- Open an issue: https://github.com/LinkForty/mobile-sdk-ios/issues
- Check docs: https://docs.linkforty.com
