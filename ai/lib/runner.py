import importlib.util
from pathlib import Path
from types import ModuleType

import model
from events import Decision, Event, combine


class HookError(Exception):
    pass


def _load_module(hooks_dir: Path, name: str) -> ModuleType:
    path = hooks_dir / f"{name}.py"
    spec = importlib.util.spec_from_file_location(f"zambelz_hook_{name}", path)

    if spec is None or spec.loader is None:
        raise HookError(f"cannot load hook module {path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    if not callable(getattr(module, "handle", None)):
        raise HookError(f"hook module {path} has no handle(event) function")

    return module


def run(ai_dir: Path, events: list[Event]) -> Decision:
    hooks_dir = ai_dir / "hooks"
    specs = model.load_hooks(hooks_dir)
    decisions: list[Decision] = []

    for spec in specs:
        subscribed = [event for event in events if event.kind in spec.events]

        if not subscribed:
            continue

        module = _load_module(hooks_dir, spec.module)

        for event in subscribed:
            decision = module.handle(event)

            if decision is None:
                continue

            if not isinstance(decision, Decision):
                raise HookError(f"hook '{spec.name}' returned {type(decision).__name__}, not a Decision")

            decisions.append(decision)

            if decision.deny:
                return combine(decisions)

    return combine(decisions)
