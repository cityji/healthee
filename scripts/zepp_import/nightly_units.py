"""What the nightly job installs: the two systemd units and the settings file.

Pure text in, text out. Nothing here touches the machine, so all of it is tested
directly; `nightly.py` does the writing.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

SERVICE = "healthee-zepp-import.service"
TIMER = "healthee-zepp-import.timer"
LOCK = "/run/lock/healthee-zepp-import.lock"
UNIT_DIR = Path("/etc/systemd/system")
TEMPLATES = Path(__file__).resolve().parents[2] / "infra" / "zepp-import"

_PLACEHOLDER = re.compile(r"\{\{([A-Z_]+)\}\}")
_TIME = re.compile(r"([01]\d|2[0-3]):([0-5]\d)")
_ZONE = re.compile(r"[A-Za-z0-9_+\-]+(/[A-Za-z0-9_+\-]+)*")

# The order the installer asks in; the names the importer reads (README, "Running it
# unattended").
LOGINS: tuple[tuple[str, str, bool], ...] = (
    ("HEALTHEE_URL", "Healthee address (the one typed into the app)", False),
    ("HEALTHEE_EMAIL", "Healthee email", False),
    ("HEALTHEE_PASSWORD", "Healthee password", True),
    ("ZEPP_EMAIL", "Zepp email", False),
    ("ZEPP_PASSWORD", "Zepp password", True),
)


@dataclass(frozen=True)
class Choice:
    """What the owner decided: who runs it, from where, when, and whether routes go in."""

    user: str
    repo: Path
    env_file: Path
    python: str
    time: str  # HH:MM
    zone: str  # an IANA name such as Asia/Kolkata
    routes: bool


def checked_time(text: str) -> str:
    """`23:30` stays `23:30`; `7:05` becomes `07:05`; anything else is refused."""
    value = text.strip()
    if len(value) == 4 and value[1] == ":":
        value = "0" + value
    if not _TIME.fullmatch(value):
        raise ValueError(f"{text!r} is not a time like 23:30")
    return value


def checked_zone(text: str, zoneinfo: Path = Path("/usr/share/zoneinfo")) -> str:
    """An IANA zone name that this machine knows."""
    value = text.strip()
    if not _ZONE.fullmatch(value) or ".." in value or not (zoneinfo / value).is_file():
        raise ValueError(f"{text!r} is not a time zone this server knows, like Asia/Kolkata")
    return value


def render(template: str, values: dict[str, str]) -> str:
    """Fill every `{{NAME}}`. A name with no value is a bug, not a blank."""
    missing = sorted({name for name in _PLACEHOLDER.findall(template) if name not in values})
    if missing:
        raise KeyError(f"no value for {', '.join(missing)}")
    return _PLACEHOLDER.sub(lambda match: values[match.group(1)], template)


def unit_values(choice: Choice) -> dict[str, str]:
    for name, path in (("repo", choice.repo), ("env file", choice.env_file)):
        if any(c.isspace() for c in str(path)):
            raise ValueError(f"the {name} path has a space in it; systemd would split it")
    return {
        "USER": choice.user,
        "REPO": str(choice.repo),
        "ENV_FILE": str(choice.env_file),
        "PYTHON": choice.python,
        "LOCK": LOCK,
        "ROUTES_FLAG": "" if choice.routes else " --no-routes",
        "TIME": choice.time,
        "ZONE": choice.zone,
    }


def units(choice: Choice, templates: Path = TEMPLATES) -> dict[str, str]:
    """File name to file text, for both units."""
    values = unit_values(choice)
    return {
        name: render((templates / f"{name}.in").read_text(encoding="utf-8"), values)
        for name in (SERVICE, TIMER)
    }


def env_text(values: dict[str, str]) -> str:
    """The settings file. Each value is double-quoted: the importer strips exactly one
    pair of matching quotes, so a password that itself starts and ends with a quote
    survives."""
    lines = ["# Healthee nightly Zepp import. Only its owner may read this file (chmod 600)."]
    for name, _, _ in LOGINS:
        value = values[name]
        if "\n" in value or "\r" in value:
            raise ValueError(f"{name} has a line break in it")
        lines.append(f'{name}="{value}"')
    return "\n".join(lines) + "\n"


def schedule_of(service_text: str, timer_text: str) -> tuple[str, bool]:
    """Read back what an installed pair says: `("23:30 Asia/Kolkata", routes_on)`."""
    when = "unknown time"
    for line in timer_text.splitlines():
        if line.startswith("OnCalendar=*-*-* "):
            clock, _, zone = line.removeprefix("OnCalendar=*-*-* ").partition(" ")
            when = f"{clock[:5]} {zone}".strip()
    return when, "--no-routes" not in service_text
