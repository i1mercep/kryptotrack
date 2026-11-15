export type Provider = "binance" | "coingecko";
export interface Coin { id: string; symbol: string; name: string }
export interface Settings {
    coin: string; coinSymbol: string; baseCurrency: string; apiProvider: Provider;
    apiKey: string; timeout: number; refreshInterval: number; show24hChange: boolean;
}
export interface Quote {
    key: string; price: number; change24h: number | null; provider: Provider;
    receivedAt: number; updatedAt: number; fallback: boolean;
}
export interface Failure { code: string; status?: number; retryAt?: number }
export interface Response { status: number; body: string; retryAfter: string }
export interface RequestSpec { url: string; headers?: Record<string, string> }
export type Cancel = () => void;
export type Schedule = (milliseconds: number, callback: () => void) => Cancel;
export type Request = (spec: RequestSpec, timeoutMs: number,
    done: (error: Failure | null, response?: Response) => void) => Cancel;
export interface State {
    quote: Quote | null; loading: boolean; error: Failure | null; retryAt: number;
}
export interface Environment {
    request: Request; schedule: Schedule; now: () => number; random: () => number;
    changed: (state: State) => void;
}
