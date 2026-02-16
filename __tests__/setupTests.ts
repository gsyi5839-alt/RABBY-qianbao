import chrome from 'sinon-chrome';
import { TextEncoder, TextDecoder } from 'util';
import * as crypto from 'crypto';

// from https://github.com/clarkbw/jest-webextension-mock/blob/master/src/setup.js
global.chrome = chrome;
(global as any).browser = chrome;

// Firefox specific globals
// if (navigator.userAgent.indexOf('Firefox') !== -1) {
// https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Content_scripts#exportFunction
(global as any).exportFunction = jest.fn((func) => func);
// https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Content_scripts#cloneInto
(global as any).cloneInto = jest.fn((obj) => obj);

// https://stackoverflow.com/questions/68468203/why-am-i-getting-textencoder-is-not-defined-in-jest
Object.assign(global, { TextDecoder, TextEncoder });

// WebCrypto is required by @metamask/browser-passworder in keyring tests.
// Jest's runtime may not expose it even on Node versions that support it.
if (!(globalThis as any).crypto?.subtle) {
  const wc = (crypto as any).webcrypto;

  // Prefer augmenting an existing JSDOM crypto object (often read-only on window/globalThis).
  const existing = (globalThis as any).crypto;
  if (existing && typeof existing === 'object') {
    if (!existing.subtle && wc?.subtle) {
      try {
        Object.defineProperty(existing, 'subtle', {
          value: wc.subtle,
          configurable: true,
        });
      } catch (e) {
        // ignore
      }
    }
    if (!existing.getRandomValues && wc?.getRandomValues) {
      try {
        Object.defineProperty(existing, 'getRandomValues', {
          value: wc.getRandomValues.bind(wc),
          configurable: true,
        });
      } catch (e) {
        // ignore
      }
    }
  }

  // If subtle is still missing, define `crypto` on globalThis if possible.
  if (!(globalThis as any).crypto?.subtle && wc) {
    try {
      Object.defineProperty(globalThis, 'crypto', {
        value: wc,
        configurable: true,
      });
    } catch (e) {
      // ignore
    }
  }
}
