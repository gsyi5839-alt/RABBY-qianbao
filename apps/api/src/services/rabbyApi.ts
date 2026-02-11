import axios, { AxiosInstance } from 'axios';
import { v4 as uuidv4 } from 'uuid';
import { config } from '../config';

const apiKey = uuidv4();

export const rabbyApi: AxiosInstance = axios.create({
  baseURL: config.rabbyApiUrl,
  timeout: 30000,
});

rabbyApi.interceptors.request.use((reqConfig) => {
  reqConfig.headers['X-API-Key'] = apiKey;
  reqConfig.headers['X-API-Time'] = Math.floor(Date.now() / 1000).toString();
  return reqConfig;
});

rabbyApi.interceptors.response.use(
  (response) => response,
  (error) => {
    if (axios.isAxiosError(error)) {
      const status = error.response?.status || 502;
      const message = error.response?.data?.message || error.message;
      const proxyError = new Error(message) as Error & { status: number };
      proxyError.status = status;
      throw proxyError;
    }
    throw error;
  }
);
