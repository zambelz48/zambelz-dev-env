from cpe import version_key

ROOT_VERSIONS = ("0", "*", "")


def _covers(entry: dict, version: str) -> bool:
    start = entry.get("version", "")
    key = version_key(version)
    lower_ok = start in ROOT_VERSIONS or key >= version_key(start)

    if "lessThan" in entry:
        return lower_ok and (entry["lessThan"] == "*" or key < version_key(entry["lessThan"]))

    if "lessThanOrEqual" in entry:
        return lower_ok and (entry["lessThanOrEqual"] == "*" or key <= version_key(entry["lessThanOrEqual"]))

    return start not in ROOT_VERSIONS and version_key(start) == key


def _same_line(listed: str, version: str) -> bool:
    return version_key(listed)[0][:1] == version_key(version)[0][:1]


def _covers_listed_line(entry: dict, version: str) -> bool:
    listed = entry.get("version", "")

    return _same_line(listed, version) and version_key(version) <= version_key(listed)


def _product_matches(spec: dict, product: str) -> bool:
    match spec.get("product_match", "exact"):
        case "contains":
            return spec["product"].lower() in product.lower()
        case _:
            return spec["product"].lower() == product.lower()


def _entries(record: dict, spec: dict) -> list[dict]:
    affected = record.get("containers", {}).get("cna", {}).get("affected", [])

    return [
        entry
        for entry in affected
        if str(entry.get("vendor", "")).lower() == spec["vendor"].lower()
        and _product_matches(spec, str(entry.get("product", "")))
    ]


def _versions(entry: dict, spec: dict) -> list[dict]:
    prefix = spec.get("version_prefix", "")
    items: list[dict] = []

    for item in entry.get("versions", []):
        version = str(item.get("version", ""))

        if prefix and not version.startswith(prefix):
            continue

        items.append({**item, "version": version.removeprefix(prefix)})

    return items


def is_affected(record: dict, specs: list[dict], version: str) -> bool:
    for spec in specs:
        covers = _covers

        if spec.get("listed_means") == "up-to-in-line":
            covers = _covers_listed_line

        for entry in _entries(record, spec):
            covering = [item.get("status") for item in _versions(entry, spec) if covers(item, version)]

            if "unaffected" in covering:
                continue

            if "affected" in covering:
                return True

            if not covering and entry.get("defaultStatus") == "affected" and not spec.get("listed_means"):
                return True

    return False
