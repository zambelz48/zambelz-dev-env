import json
import re
import time

import procs

RETRIES = 3
TRANSIENT = re.compile(
    r"TLS handshake timeout|i/o timeout|connection reset|connection refused|unexpected EOF"
    r"|no such host|HTTP 50[0234]|HTTP 429|secondary rate limit",
    re.IGNORECASE,
)


class GitHubError(Exception):
    pass


def _gh(args: list[str]) -> str:
    for attempt in range(RETRIES):
        try:
            return procs.checked(["gh", "api", *args])
        except procs.CommandError as error:
            if attempt == RETRIES - 1 or not TRANSIENT.search(str(error)):
                raise GitHubError(str(error)) from error

        time.sleep(2**attempt)

    raise GitHubError(f"gh api {args[0]} failed {RETRIES} times")


def _json(text: str, what: str) -> object:
    try:
        return json.loads(text)
    except json.JSONDecodeError as error:
        raise GitHubError(f"gh api {what} returned invalid JSON: {error}") from error


def raw_file(repo: str, path: str, ref: str) -> str:
    return _gh([f"repos/{repo}/contents/{path}?ref={ref}", "-H", "Accept: application/vnd.github.raw"])


def json_get(endpoint: str, paginate: bool = False) -> object:
    args = [endpoint]

    if paginate:
        args = ["--paginate", "--slurp", endpoint]

    return _json(_gh(args), endpoint)


def graphql(query: str, variables: dict[str, str]) -> dict:
    args = ["graphql", "-f", f"query={query}"]

    for name, value in variables.items():
        args += ["-f", f"{name}={value}"]

    answer = _json(_gh(args), "graphql")

    if not isinstance(answer, dict) or answer.get("errors") or "data" not in answer:
        raise GitHubError(f"gh api graphql failed: {answer.get('errors') if isinstance(answer, dict) else answer}")

    return answer["data"]
