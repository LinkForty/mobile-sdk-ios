# Contributing to LinkForty iOS SDK

Thank you for considering contributing to the LinkForty iOS SDK! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **iOS version** and device
- **SDK version**
- **Code samples** if applicable
- **Crash logs** if applicable

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Clear title and description**
- **Use case** and motivation
- **Proposed solution** or API design
- **Alternatives considered**

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`swift test`)
6. Run SwiftLint (`swiftlint`)
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

## Development Setup

### Prerequisites

- macOS with Xcode 14.0+
- Swift 5.9+
- SwiftLint (install via `brew install swiftlint`)

### Building the Project

```bash
# Clone the repository
git clone https://github.com/LinkForty/mobile-sdk-ios.git
cd mobile-sdk-ios

# Build with SPM
swift build

# Run tests
swift test
```

### Project Structure

```
mobile-sdk-ios/
├── Sources/LinkFortySDK/
│   ├── Models/           # Data models
│   ├── Network/          # HTTP client
│   ├── Storage/          # Data persistence
│   ├── Fingerprint/      # Device fingerprinting
│   ├── Attribution/      # Attribution logic
│   ├── DeepLink/         # Deep link handling
│   ├── Events/           # Event tracking
│   ├── Utilities/        # Helper functions
│   └── Resources/        # Privacy manifest, etc.
├── Tests/                # Unit and integration tests
├── Examples/             # Example apps
└── docs/                 # Documentation
```

## Coding Standards

### Swift Style Guide

- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint to enforce style (see `.swiftlint.yml`)
- Maximum line length: 120 characters
- Use 4 spaces for indentation (no tabs)

### Code Organization

- One type per file (classes, structs, enums)
- Group related functionality together
- Use `// MARK: -` to separate sections
- Keep files under 400 lines when possible

### Naming Conventions

- Use descriptive, clear names
- Prefer clarity over brevity
- Use camelCase for variables and functions
- Use PascalCase for types
- Prefix protocols with `Protocol` suffix if needed (e.g., `URLSessionProtocol`)

### Documentation

- Document all public APIs with DocC-style comments
- Include usage examples for complex APIs
- Document thrown errors
- Document thread safety considerations

Example:
```swift
/// Tracks a custom event with optional properties.
///
/// Events are queued and sent to the backend asynchronously. If the network is unavailable,
/// events are queued and retried automatically.
///
/// - Parameters:
///   - name: The event name (e.g., "purchase", "signup")
///   - properties: Optional event properties (must be JSON-serializable)
/// - Throws: `LinkFortyError.notInitialized` if SDK not initialized
/// - Note: This method is thread-safe
public func trackEvent(name: String, properties: [String: Any]?) async throws {
    // Implementation
}
```

## Testing Guidelines

### Unit Tests

- Write tests for all new functionality
- Aim for 80%+ code coverage
- Use descriptive test names: `testReportInstallAttributedResponse`
- Follow Arrange-Act-Assert pattern
- Mock external dependencies

Example:
```swift
func testSaveAndRetrieveInstallId() {
    // Arrange
    let storage = StorageManager(userDefaults: mockUserDefaults)
    let testId = "test-install-id-123"

    // Act
    storage.saveInstallId(testId)
    let retrieved = storage.getInstallId()

    // Assert
    XCTAssertEqual(retrieved, testId)
}
```

### Integration Tests

- Test against real backend (local Core instance)
- Test end-to-end flows
- Test error scenarios
- Clean up test data after each test

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter LinkFortySDKTests.StorageManagerTests

# Run with coverage
swift test --enable-code-coverage
```

## Privacy & Security

### Privacy Requirements

- Never collect IDFA without explicit user consent
- Minimize data collection
- Update Privacy Manifest for any new data collection
- Document privacy implications of changes

### Security Requirements

- Never log sensitive data (API keys, tokens)
- Use HTTPS for all network requests (except localhost)
- Validate all user inputs
- Follow secure coding practices

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Adding or updating tests
- `refactor:` Code refactoring
- `perf:` Performance improvements
- `chore:` Maintenance tasks

Examples:
```
feat: add offline event queueing
fix: prevent double initialization crash
docs: update README with Universal Links setup
test: add integration tests for attribution
```

## Release Process

1. Update version in `Package.swift`
2. Update `CHANGELOG.md`
3. Create git tag (`v1.0.0`)
4. Push tag to trigger release workflow
5. Update documentation

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to LinkForty iOS SDK!
