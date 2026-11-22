import json
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

USER_AGENT = "zconf-audit"
TIMEOUT_SECONDS = 60
RETRIES = 5
NVD_HOST = "services.nvd.nist.gov"
NVD_WINDOW_SECONDS = 30
NVD_REQUESTS_WITH_KEY = 50
NVD_REQUESTS_WITHOUT_KEY = 5
RETRYABLE = (403, 429, 500, 502, 503, 504)


class WebError(Exception):
    pass


class _Window:
    def __init__(self, requests: int, seconds: float):
        self.requests = requests
        self.seconds = seconds
        self.sent: list[float] = []
        self.lock = threading.Lock()

    def wait(self) -> None:
        with self.lock:
            now = time.monotonic()
            self.sent = [stamp for stamp in self.sent if now - stamp < self.seconds]

            if len(self.sent) >= self.requests:
                time.sleep(self.seconds - (now - self.sent[0]) + 0.1)
                now = time.monotonic()
                self.sent = [stamp for stamp in self.sent if now - stamp < self.seconds]

            self.sent.append(now)


def nvd_key() -> str | None:
    return os.environ.get("NVD_API_KEY") or None


def _nvd_requests() -> int:
    if nvd_key():
        return NVD_REQUESTS_WITH_KEY

    return NVD_REQUESTS_WITHOUT_KEY


_WINDOWS = {NVD_HOST: _Window(_nvd_requests(), NVD_WINDOW_SECONDS)}


def _headers(url: str) -> dict[str, str]:
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    key = nvd_key()

    if urllib.parse.urlparse(url).hostname == NVD_HOST and key:
        headers["apiKey"] = key

    return headers


def _open(request: urllib.request.Request) -> bytes:
    host = urllib.parse.urlparse(request.full_url).hostname or ""
    window = _WINDOWS.get(host)
    last_error = ""

    for attempt in range(RETRIES):
        if window is not None:
            window.wait()

        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            last_error = f"HTTP {error.code} from {host}"

            if error.code not in RETRYABLE:
                break
        except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
            last_error = f"{host}: {error}"

        time.sleep(2**attempt)

    raise WebError(f"{last_error} ({request.full_url})")


def _json(body: bytes, url: str) -> object:
    try:
        return json.loads(body)
    except json.JSONDecodeError as error:
        raise WebError(f"{url} returned invalid JSON: {error}") from error


def get_json(url: str, params: dict | None = None) -> object:
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"

    return _json(_open(urllib.request.Request(url, headers=_headers(url))), url)


def get_text(url: str) -> str:
    return _open(urllib.request.Request(url, headers=_headers(url))).decode()


def post_json(url: str, payload: object) -> object:
    data = json.dumps(payload).encode()
    headers = {**_headers(url), "Content-Type": "application/json"}

    return _json(_open(urllib.request.Request(url, data=data, headers=headers, method="POST")), url)
