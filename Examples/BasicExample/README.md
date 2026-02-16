# BasicExample - LinkForty iOS SDK

A simple SwiftUI app demonstrating all features of the LinkForty iOS SDK.

## Features Demonstrated

- ✅ SDK initialization with configuration
- ✅ Install attribution tracking
- ✅ Deferred deep link handling (install attribution)
- ✅ Direct deep link handling (Universal Links)
- ✅ Event tracking
- ✅ Revenue tracking
- ✅ Event queue management
- ✅ Programmatic link creation
- ✅ Data management (clear/reset)

## Running the Example

### Prerequisites

1. **LinkForty Backend**: You need a running LinkForty backend (Core or Cloud)
2. **API Key**: Get your API key from your LinkForty dashboard (or omit for self-hosted Core)

### Setup

1. Open the project:
   ```bash
   cd Examples/BasicExample
   open BasicExample.xcodeproj
   ```

2. Update the API configuration in `BasicExampleApp.swift`:
   ```swift
   let config = LinkFortyConfig(
       baseURL: URL(string: "https://your-linkforty-instance.com")!,
       apiKey: "your-api-key-here", // Optional for self-hosted
       debug: true
   )
   ```

3. For Universal Links (optional):
   - Enable "Associated Domains" capability
   - Add your domain: `applinks:your-linkforty-instance.com`
   - Ensure your backend serves the AASA file

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
- Verify your API key (if using LinkForty Cloud)
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
