// Jest-only shim for the ESM-only `multiformats` package.
//
// The extension build (webpack) can consume the real ESM module. Jest (via ts-jest)
// resolves modules as CommonJS and can't satisfy packages that only export "import".
// For unit tests in this repo we only need a minimal `CID.parse(...).toV1().toString()` API.

export const CID = {
  parse: (input: string) => ({
    toV1: () => ({
      toString: () => input,
    }),
  }),
};

