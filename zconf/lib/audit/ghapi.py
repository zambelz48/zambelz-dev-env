import json

import procs


class GitHubError(Exception):
    pass


def _gh(args: list[str]) -> str:
    try:
        return procs.checked(["gh", "api", *args])
    except procs.CommandError as error:
        raise GitHubError(str(error)) from error


def raw_file(repo: str, path: str, ref: str) -> str:
    return _gh([f"repos/{repo}/contents/{path}?ref={ref}", "-H", "Accept: application/vnd.github.raw"])


def json_get(endpoint: str, paginate: bool = False) -> object:
    args = [endpoint]

    if paginate:
        args = ["--paginate", "--slurp", endpoint]

    text = _gh(args)

    try:
        return json.loads(text)
    except json.JSONDecodeError as error:
        raise GitHubError(f"gh api {endpoint} returned invalid JSON: {error}") from error
