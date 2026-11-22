import sys
from collections import Counter

MARKERS = ("CHANGED", "OK", "WARN", "ERROR")


class Report:
    def __init__(self) -> None:
        self.counts: Counter[str] = Counter()

    def _emit(self, marker: str, message: str, fix: str) -> None:
        self.counts[marker] += 1
        print(f"{marker}: {message}")

        if fix:
            print(f"  fix: {fix}")

    def ok(self, message: str) -> None:
        self._emit("OK", message, "")

    def changed(self, message: str) -> None:
        self._emit("CHANGED", message, "")

    def warn(self, message: str, fix: str = "") -> None:
        self._emit("WARN", message, fix)

    def error(self, message: str, fix: str = "") -> None:
        self._emit("ERROR", message, fix)

    def has_errors(self) -> bool:
        return self.counts["ERROR"] > 0

    def summary(self) -> None:
        print(
            f"Summary: {self.counts['CHANGED']} changed, {self.counts['OK']} ok, "
            f"{self.counts['WARN']} warnings, {self.counts['ERROR']} errors"
        )


def usage_error(message: str, usage: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    print(usage, file=sys.stderr)

    return 2
