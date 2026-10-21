#!/usr/bin/env node
// Runs the end-to-end scenarios on an iOS simulator. See E2E/README.md.

import { execFileSync } from 'node:child_process';
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readEnv, runScenarios } from './harness.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const bundleId = 'com.linkforty.e2e';
const appPath = join(here, 'build/Build/Products/Debug-iphonesimulator/LFE2E.app');
const simulatorName = process.env.LF_E2E_SIMULATOR ?? 'LinkForty E2E';

const simctl = (...args) =>
  execFileSync('xcrun', ['simctl', ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
const quiet = (...args) => {
  try {
    return simctl(...args);
  } catch {
    return '';
  }
};

function build() {
  execFileSync('xcodegen', ['generate', '--quiet'], { cwd: here, stdio: 'inherit' });
  execFileSync('xcodebuild', [
    '-project', 'LFE2E.xcodeproj', '-scheme', 'LFE2E', '-sdk', 'iphonesimulator',
    '-configuration', 'Debug', '-derivedDataPath', 'build', '-quiet', 'build',
  ], { cwd: here, stdio: 'inherit' });
}

/** The named simulator, created on the newest iOS runtime if missing, booted. */
function simulator() {
  const devices = JSON.parse(simctl('list', 'devices', '-j')).devices;
  let udid = Object.values(devices).flat().find((d) => d.name === simulatorName && d.isAvailable)?.udid;
  if (!udid) {
    const runtime = JSON.parse(simctl('list', 'runtimes', '-j')).runtimes
      .filter((r) => r.platform === 'iOS' && r.isAvailable).at(-1);
    const type = runtime.supportedDeviceTypes.filter((d) => d.productFamily === 'iPhone').at(-1);
    udid = simctl('create', simulatorName, type.identifier, runtime.identifier);
  }
  quiet('boot', udid);
  simctl('bootstatus', udid, '-b');
  return udid;
}

function iosDevice(udid) {
  const container = () => simctl('get_app_container', udid, bundleId, 'data');
  return {
    platform: 'iOS',
    sdkName: 'ios',
    async reinstall() {
      quiet('terminate', udid, bundleId);
      quiet('uninstall', udid, bundleId);
      simctl('install', udid, appPath);
    },
    async writeConfig(config) {
      writeFileSync(join(container(), 'Documents/lfe2e-config.json'), JSON.stringify(config));
    },
    async launch(args) {
      const argv = Object.entries(args).flatMap(([k, v]) => [`-lf${k[0].toUpperCase()}${k.slice(1)}`, String(v)]);
      simctl('launch', udid, bundleId, ...argv);
    },
    async terminate() {
      quiet('terminate', udid, bundleId);
    },
    async sendCommand(command) {
      appendFileSync(join(container(), 'Documents/lfe2e-commands.jsonl'), `${JSON.stringify(command)}\n`);
    },
    async openInBrowser(url) {
      simctl('openurl', udid, url);
    },
    async background() {
      simctl('launch', udid, 'com.apple.Preferences');
    },
    async foreground() {
      simctl('launch', udid, bundleId);
    },
    async closeBrowser() {
      quiet('terminate', udid, 'com.apple.mobilesafari');
    },
    async readLog() {
      const file = join(container(), 'Documents/lfe2e.jsonl');
      if (!existsSync(file)) return [];
      return readFileSync(file, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line));
    },
  };
}

if (!process.argv.includes('--no-build')) build();
const udid = simulator();
const ok = await runScenarios({
  env: readEnv(),
  device: iosDevice(udid),
  reportPath: join(here, 'build/e2e-report.json'),
});
process.exit(ok ? 0 : 1);
