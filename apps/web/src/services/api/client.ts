/**
 * HTTP Client for Rabby Web API
 *
 * A fetch-based HTTP client wrapping the Rabby OpenAPI endpoints.
 * Base URL: https://api.rabby.io
 *
 * Features:
 * - GET/POST with typed responses
 * - Unified error handling via ApiError
 * - Request timeout (default 30s)
 * - Optional automatic retry with exponential backoff
 * - Request/response interceptors
 */

// ---------------------------------------------------------------------------
// Error Types
// ---------------------------------------------------------------------------

export class ApiError extends Error {
  public readonly status: number;
  public readonly statusText: string;
  public readonly url: string;
  public readonly body: unknown;

  constructor(options: {
    message: string;
    status: number;
    statusText: string;
    url: string;
    body?: unknown;
  }) {
    super(options.message);
    this.name = 'ApiError';
    this.status = options.status;
    this.statusText = options.statusText;
    this.url = options.url;
    this.body = options.body;
  }
}

export class ApiTimeoutError extends Error {
  public readonly url: string;
  public readonly timeout: number;

  constructor(url: string, timeout: number) {
    super(`Request to ${url} timed out after ${timeout}ms`);
    this.name = 'ApiTimeoutError';
    this.url = url;
    this.timeout = timeout;
  }
}

export class ApiNetworkError extends Error {
  public readonly url: string;
  public readonly cause: unknown;

  constructor(url: string, cause: unknown) {
    const msg =
      cause instanceof Error ? cause.message : 'Unknown network error';
    super(`Network error for ${url}: ${msg}`);
    this.name = 'ApiNetworkError';
    this.url = url;
    this.cause = cause;
  }
}

// ---------------------------------------------------------------------------
// Interceptor Types
// ---------------------------------------------------------------------------

export type RequestInterceptor = (
  url: string,
  init: RequestInit,
) => RequestInit | Promise<RequestInit>;

export type ResponseInterceptor = (
  response: Response,
  url: string,
) => Response | Promise<Response>;

// ---------------------------------------------------------------------------
// Client Options
// ---------------------------------------------------------------------------

export interface ApiClientOptions {
  /** Base URL for all requests (default: https://api.rabby.io) */
  baseUrl?: string;
  /** Default request timeout in milliseconds (default: 30000) */
  timeout?: number;
  /** Number of automatic retries on failure (default: 0 = no retry) */
  retries?: number;
  /** Base delay between retries in ms, doubled each attempt (default: 1000) */
  retryDelay?: number;
  /** HTTP status codes eligible for retry (default: [408, 429, 500, 502, 503, 504]) */
  retryableStatusCodes?: number[];
  /** Default headers merged into every request */
  headers?: Record<string, string>;
}

// ---------------------------------------------------------------------------
// API Client
// ---------------------------------------------------------------------------

export interface ApiClient {
  /** Send a GET request */
  get<T = unknown>(
    path: string,
    params?: Record<string, string | number | boolean | undefined | null>,
    options?: { timeout?: number; signal?: AbortSignal },
  ): Promise<T>;

  /** Send a POST request */
  post<T = unknown>(
    path: string,
    body?: unknown,
    options?: { timeout?: number; signal?: AbortSignal },
  ): Promise<T>;

  /** Register a request interceptor. Returns an unsubscribe function. */
  onRequest(interceptor: RequestInterceptor): () => void;

  /** Register a response interceptor. Returns an unsubscribe function. */
  onResponse(interceptor: ResponseInterceptor): () => void;
}

// ---------------------------------------------------------------------------
// Implementation helpers
// ---------------------------------------------------------------------------

function buildUrl(
  base: string,
  path: string,
  params?: Record<string, string | number | boolean | undefined | null>,
): string {
  // Normalise: remove trailing slash from base, ensure leading slash on path
  const normBase = base.replace(/\/+$/, '');
  const normPath = path.startsWith('/') ? path : `/${path}`;
  const url = new URL(`${normBase}${normPath}`);

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null) {
        url.searchParams.append(key, String(value));
      }
    }
  }
  return url.toString();
}

async function parseResponseBody(response: Response): Promise<unknown> {
  const contentType = response.headers.get('content-type') ?? '';
  if (contentType.includes('application/json')) {
    return response.json();
  }
  // Attempt JSON parse for responses without explicit content-type
  const text = await response.text();
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

const DEFAULT_BASE_URL = 'https://api.rabby.io';
const DEFAULT_TIMEOUT = 30_000;
const DEFAULT_RETRYABLE_STATUS_CODES = [408, 429, 500, 502, 503, 504];

export function createApiClient(options: ApiClientOptions = {}): ApiClient {
  const {
    baseUrl = DEFAULT_BASE_URL,
    timeout: defaultTimeout = DEFAULT_TIMEOUT,
    retries = 0,
    retryDelay = 1000,
    retryableStatusCodes = DEFAULT_RETRYABLE_STATUS_CODES,
    headers: defaultHeaders = {},
  } = options;

  const requestInterceptors: RequestInterceptor[] = [];
  const responseInterceptors: ResponseInterceptor[] = [];

  // ------- internal fetch with timeout, interceptors, retry -------

  async function doFetch<T>(
    url: string,
    init: RequestInit,
    timeoutMs: number,
    externalSignal?: AbortSignal,
  ): Promise<T> {
    // Apply request interceptors
    let finalInit = { ...init };
    for (const interceptor of requestInterceptors) {
      finalInit = await interceptor(url, finalInit);
    }

    // Merge default headers
    finalInit.headers = {
      ...defaultHeaders,
      ...(finalInit.headers as Record<string, string>),
    };

    let lastError: unknown;

    for (let attempt = 0; attempt <= retries; attempt++) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);

      // If the caller passed an external signal, forward its abort
      const onExternalAbort = () => controller.abort();
      externalSignal?.addEventListener('abort', onExternalAbort, {
        once: true,
      });

      try {
        let response = await fetch(url, {
          ...finalInit,
          signal: controller.signal,
        });

        // Apply response interceptors
        for (const interceptor of responseInterceptors) {
          response = await interceptor(response, url);
        }

        if (!response.ok) {
          const body = await parseResponseBody(response);

          // Decide whether to retry
          if (
            attempt < retries &&
            retryableStatusCodes.includes(response.status)
          ) {
            lastError = new ApiError({
              message: `HTTP ${response.status}: ${response.statusText}`,
              status: response.status,
              statusText: response.statusText,
              url,
              body,
            });
            await sleep(retryDelay * Math.pow(2, attempt));
            continue;
          }

          throw new ApiError({
            message: `HTTP ${response.status}: ${response.statusText}`,
            status: response.status,
            statusText: response.statusText,
            url,
            body,
          });
        }

        const data = await parseResponseBody(response);
        return data as T;
      } catch (error: unknown) {
        if (error instanceof ApiError) {
          throw error;
        }

        // Timeout (AbortError from our controller)
        if (
          error instanceof DOMException &&
          error.name === 'AbortError'
        ) {
          if (externalSignal?.aborted) {
            throw new ApiNetworkError(url, new Error('Request was cancelled'));
          }
          if (attempt < retries) {
            lastError = new ApiTimeoutError(url, timeoutMs);
            await sleep(retryDelay * Math.pow(2, attempt));
            continue;
          }
          throw new ApiTimeoutError(url, timeoutMs);
        }

        // Network error
        if (attempt < retries) {
          lastError = error;
          await sleep(retryDelay * Math.pow(2, attempt));
          continue;
        }

        throw new ApiNetworkError(url, error);
      } finally {
        clearTimeout(timer);
        externalSignal?.removeEventListener('abort', onExternalAbort);
      }
    }

    // Should not be reached, but just in case:
    throw lastError ?? new Error('Unexpected fetch failure');
  }

  // ------- public API -------

  const client: ApiClient = {
    async get<T = unknown>(
      path: string,
      params?: Record<
        string,
        string | number | boolean | undefined | null
      >,
      options?: { timeout?: number; signal?: AbortSignal },
    ): Promise<T> {
      const url = buildUrl(baseUrl, path, params);
      return doFetch<T>(
        url,
        { method: 'GET' },
        options?.timeout ?? defaultTimeout,
        options?.signal,
      );
    },

    async post<T = unknown>(
      path: string,
      body?: unknown,
      options?: { timeout?: number; signal?: AbortSignal },
    ): Promise<T> {
      const url = buildUrl(baseUrl, path);
      const init: RequestInit = {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: body !== undefined ? JSON.stringify(body) : undefined,
      };
      return doFetch<T>(
        url,
        init,
        options?.timeout ?? defaultTimeout,
        options?.signal,
      );
    },

    onRequest(interceptor: RequestInterceptor): () => void {
      requestInterceptors.push(interceptor);
      return () => {
        const idx = requestInterceptors.indexOf(interceptor);
        if (idx !== -1) requestInterceptors.splice(idx, 1);
      };
    },

    onResponse(interceptor: ResponseInterceptor): () => void {
      responseInterceptors.push(interceptor);
      return () => {
        const idx = responseInterceptors.indexOf(interceptor);
        if (idx !== -1) responseInterceptors.splice(idx, 1);
      };
    },
  };

  return client;
}

// ---------------------------------------------------------------------------
// Default singleton client instance
// ---------------------------------------------------------------------------

export const apiClient = createApiClient();
