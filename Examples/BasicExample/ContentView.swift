//
//  ContentView.swift
//  BasicExample
//
//  Copyright (c) 2025 LinkForty
//  Licensed under the MIT License
//

import SwiftUI
import LinkFortySDK

@available(iOS 14.0, *)
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Section
                    StatusSection(appState: appState)

                    Divider()

                    // Attribution Section
                    AttributionSection(appState: appState)

                    Divider()

                    // Events Section
                    EventsSection(appState: appState)

                    Divider()

                    // Link Creation Section
                    LinkCreationSection(appState: appState)

                    Divider()

                    // Deep Link Section
                    DeepLinkSection(appState: appState)

                    Divider()

                    // Data Management Section
                    DataManagementSection(appState: appState)

                    if let error = appState.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("LinkForty Example")
        }
    }
}

@available(iOS 14.0, *)
struct StatusSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SDK Status")
                .font(.headline)

            HStack {
                Text("Initialized:")
                Spacer()
                Image(systemName: appState.isInitialized ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(appState.isInitialized ? .green : .red)
            }

            HStack {
                Text("Events Tracked:")
                Spacer()
                Text("\(appState.eventCount)")
                    .fontWeight(.bold)
            }

            HStack {
                Text("Queued Events:")
                Spacer()
                Text("\(appState.queuedEvents)")
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

@available(iOS 14.0, *)
struct AttributionSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Attribution")
                .font(.headline)

            if let installId = appState.installId {
                HStack {
                    Text("Install ID:")
                    Spacer()
                    Text(installId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("Attributed:")
                Spacer()
                Image(systemName: appState.isAttributed ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(appState.isAttributed ? .green : .gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

@available(iOS 14.0, *)
struct EventsSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Track Events")
                .font(.headline)

            Button(action: {
                appState.trackEvent(name: "button_clicked")
            }) {
                HStack {
                    Image(systemName: "hand.tap")
                    Text("Track Button Click")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            Button(action: {
                appState.trackEvent(name: "page_viewed")
            }) {
                HStack {
                    Image(systemName: "eye")
                    Text("Track Page View")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            Button(action: {
                appState.trackRevenue(amount: 29.99, currency: "USD")
            }) {
                HStack {
                    Image(systemName: "dollarsign.circle")
                    Text("Track Revenue ($29.99)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            Button(action: {
                appState.flushEvents()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Flush Event Queue")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

@available(iOS 14.0, *)
struct LinkCreationSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Link Creation")
                .font(.headline)

            Button(action: {
                appState.createLink()
            }) {
                HStack {
                    Image(systemName: "link.badge.plus")
                    Text("Create Short Link")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            if let url = appState.createdLinkURL {
                VStack(alignment: .leading, spacing: 5) {
                    Text("URL: \(url)")
                        .font(.caption)
                    if let shortCode = appState.createdLinkShortCode {
                        Text("Short Code: \(shortCode)")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

@available(iOS 14.0, *)
struct DeepLinkSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deep Link Data")
                .font(.headline)

            if let data = appState.deepLinkData {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Short Code: \(data.shortCode)")
                        .font(.caption)

                    if let iosURL = data.iosURL {
                        Text("iOS URL: \(iosURL)")
                            .font(.caption)
                    }

                    if let deepLinkPath = data.deepLinkPath {
                        Text("Deep Link Path: \(deepLinkPath)")
                            .font(.caption)
                    }

                    if let appScheme = data.appScheme {
                        Text("App Scheme: \(appScheme)")
                            .font(.caption)
                    }

                    if let linkId = data.linkId {
                        Text("Link ID: \(linkId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let utm = data.utmParameters {
                        if let source = utm.source {
                            Text("UTM Source: \(source)")
                                .font(.caption)
                        }
                        if let campaign = utm.campaign {
                            Text("UTM Campaign: \(campaign)")
                                .font(.caption)
                        }
                    }

                    if let params = data.customParameters, !params.isEmpty {
                        Text("Custom Params: \(params.count)")
                            .font(.caption)
                    }
                }
            } else {
                Text("No deep link data")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

@available(iOS 14.0, *)
struct DataManagementSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data Management")
                .font(.headline)

            Button(action: {
                appState.clearData()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Data")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

@available(iOS 14.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
