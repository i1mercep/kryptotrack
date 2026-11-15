// Only the Qt XHR surface used by production code. No browser or Node globals.
interface XMLHttpRequest {
    readyState: number;
    status: number;
    responseText: string;
    onreadystatechange: (() => void) | null;
    open(method: string, url: string, async: boolean): void;
    setRequestHeader(name: string, value: string): void;
    getResponseHeader(name: string): string | null;
    send(): void;
    abort(): void;
}
