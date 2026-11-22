import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

DEFAULT_TIMEOUT_SECONDS = 300


class CommandError(Exception):
    pass


@dataclass(frozen=True)
class Completed:
    code: int
    stdout: str
    stderr: str


def mise_data_dir() -> Path:
    return Path(os.environ.get("MISE_DATA_DIR") or Path.home() / ".local/share/mise")


def no_install_env() -> dict[str, str]:
    shims = str(mise_data_dir() / "shims")
    path = os.pathsep.join(part for part in os.environ.get("PATH", "").split(os.pathsep) if part != shims)
    env = dict(os.environ)

    env.update(
        {
            "PATH": path,
            "MISE_AUTO_INSTALL": "false",
            "MISE_NOT_FOUND_AUTO_INSTALL": "false",
            "GOTOOLCHAIN": "local",
        }
    )

    return env


def run(
    argv: list[str],
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    stdin: str | None = None,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> Completed:
    try:
        done = subprocess.run(
            argv,
            cwd=cwd,
            env=env,
            input=stdin,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError as error:
        raise CommandError(f"{argv[0]} is not installed") from error
    except subprocess.TimeoutExpired as error:
        raise CommandError(f"{' '.join(argv[:3])} did not finish within {timeout} seconds") from error

    return Completed(code=done.returncode, stdout=done.stdout, stderr=done.stderr)


def checked(argv: list[str], cwd: Path | None = None, env: dict[str, str] | None = None) -> str:
    done = run(argv, cwd=cwd, env=env)

    if done.code != 0:
        detail = (done.stderr or done.stdout).strip().splitlines()[-1:] or [""]
        raise CommandError(f"{' '.join(argv[:4])} exited {done.code}: {detail[0]}")

    return done.stdout
