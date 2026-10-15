"""`zepp-nightly`: install, check and remove the nightly Zepp import on a Linux server.

    sudo python3 scripts/zepp-nightly install --time 23:30 --no-routes
    zepp-nightly status
    sudo zepp-nightly uninstall

`install` asks for the two logins once (passwords hidden), keeps them in a file only the
owner can read, writes the systemd units and turns the timer on. Everything that changes
the machine goes through `Machine`, so the tests run `main` against a fake one.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from getpass import getpass
from pathlib import Path

from zepp_import import failures, nightly_status
from zepp_import.nightly_units import (
    LOGINS,
    SERVICE,
    TIMER,
    UNIT_DIR,
    Choice,
    checked_time,
    checked_zone,
    env_text,
    units,
)
from zepp_import.prompts import load_env_file

REPO = Path(__file__).resolve().parents[2]
LINK = Path("/usr/local/bin/zepp-nightly")
ENV_NAME = Path(".config/healthee-zepp-import/env")


@dataclass
class Machine:
    """Every outside effect `zepp-nightly` has. `real()` is the server; tests fake it."""

    is_root: bool
    sudo_user: str | None
    home_of: Callable[[str], Path]
    ids_of: Callable[[str], tuple[int, int]]
    run: nightly_status.Run
    ask: Callable[[str], str]
    ask_secret: Callable[[str], str]
    out: Callable[[str], None]
    unit_dir: Path = UNIT_DIR
    link: Path = LINK
    zoneinfo: Path = Path("/usr/share/zoneinfo")
    chown: Callable[[Path, int, int], None] = field(default=os.chown)
    owner_of: Callable[[Path], int] = field(default=lambda path: path.stat().st_uid)

    @staticmethod
    def real() -> Machine:
        import pwd

        def run(argv: Sequence[str]) -> tuple[int, str]:
            done = subprocess.run(list(argv), capture_output=True, text=True, check=False)
            return done.returncode, done.stdout

        def ids_of(user: str) -> tuple[int, int]:
            entry = pwd.getpwnam(user)
            return entry.pw_uid, entry.pw_gid

        return Machine(
            is_root=os.geteuid() == 0,
            sudo_user=os.environ.get("SUDO_USER"),
            home_of=lambda user: Path(pwd.getpwnam(user).pw_dir),
            ids_of=ids_of,
            run=run,
            ask=input,
            ask_secret=getpass,
            out=lambda line: print(line, flush=True),
        )


class RefusedError(Exception):
    """A plain sentence for the owner; nothing has been changed yet when it is raised."""


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="zepp-nightly", description="Run the Zepp import every night."
    )
    jobs = parser.add_subparsers(dest="job", required=True)
    install = jobs.add_parser("install", help="ask for the logins and turn the timer on")
    install.add_argument("--time", required=True, help="when to run each night, like 23:30")
    install.add_argument("--zone", default="Asia/Kolkata", help="the time zone of --time")
    routes = install.add_mutually_exclusive_group(required=True)
    routes.add_argument("--routes", action="store_true", help="import GPS routes too")
    routes.add_argument("--no-routes", action="store_true", help="import workouts only")
    logins = install.add_mutually_exclusive_group()
    logins.add_argument(
        "--new-logins", action="store_true", help="ask for the logins again, replacing the file"
    )
    logins.add_argument(
        "--env-file",
        type=Path,
        help="use logins you already keep in this file (chmod 600, yours) instead of asking",
    )
    jobs.add_parser("status", help="did the last run work")
    jobs.add_parser("uninstall", help="turn it off and remove the units (keeps the logins)")
    return parser


def main(argv: Sequence[str] | None = None, machine: Machine | None = None) -> int:
    args = _parser().parse_args(argv)
    machine = machine or Machine.real()
    try:
        if args.job == "status":
            facts = nightly_status.gather(machine.run, lambda name: _read(machine, name))
            for line in nightly_status.report(facts):
                machine.out(line)
            return 0 if not facts.started or facts.result == "success" else 1
        user = _owner(machine)
        if args.job == "uninstall":
            return _uninstall(machine, user)
        return _install(args, machine, user)
    except RefusedError as refusal:
        machine.out(str(refusal))
        return 1
    except (KeyboardInterrupt, EOFError):
        machine.out("")
        machine.out("Stopped. Nothing was turned on.")
        return 130


def _read(machine: Machine, name: str) -> str | None:
    try:
        return (machine.unit_dir / name).read_text(encoding="utf-8")
    except FileNotFoundError:
        return None


def _owner(machine: Machine) -> str:
    """The person who typed `sudo`. The import runs as them, never as root."""
    if not machine.is_root:
        raise RefusedError("This needs sudo. Run it again with sudo in front.")
    if not machine.sudo_user or machine.sudo_user == "root":
        raise RefusedError("Run it with sudo from your own login, not as root, so it runs as you.")
    return machine.sudo_user


def _install(args: argparse.Namespace, machine: Machine, user: str) -> int:
    try:
        choice = Choice(
            user=user,
            repo=REPO,
            env_file=_env_path(args, machine, user),
            python=sys.executable or "/usr/bin/python3",
            time=checked_time(args.time),
            zone=checked_zone(args.zone, machine.zoneinfo),
            routes=bool(args.routes),
        )
        texts = units(choice)
    except ValueError as error:
        raise RefusedError(f"Not installed: {error}.") from None
    if args.env_file is None:
        _logins(machine, choice, user, fresh=args.new_logins)
    else:
        _checked_env_file(machine, choice.env_file, user)
    for name, text in texts.items():
        (machine.unit_dir / name).write_text(text, encoding="utf-8")
    for argv in (["systemctl", "daemon-reload"], ["systemctl", "enable", "--now", TIMER]):
        status, _ = machine.run(argv)
        if status != 0:
            raise RefusedError(f"systemd refused: {' '.join(argv)}. Nothing runs yet.")
    _link(machine)
    routes = "with routes" if choice.routes else "without routes"
    machine.out("")
    machine.out(f"Done. Zepp import runs every night at {choice.time} {choice.zone}, {routes}.")
    machine.out("  Check it any time:  zepp-nightly status")
    machine.out("  Run it once now:    sudo systemctl start healthee-zepp-import")
    return 0


def _env_path(args: argparse.Namespace, machine: Machine, user: str) -> Path:
    given: Path | None = args.env_file
    return machine.home_of(user) / ENV_NAME if given is None else given.resolve()


def _checked_env_file(machine: Machine, path: Path, user: str) -> None:
    """An owner's own file: theirs, private, and holding every login a run needs."""
    try:
        values = load_env_file(path)
    except failures.ZeppImportError as problem:
        raise RefusedError(f"Not installed: {problem.headline}") from None
    if machine.owner_of(path) != machine.ids_of(user)[0]:
        raise RefusedError(f"Not installed: {path} must belong to {user}, who runs the import.")
    zepp = ("ZEPP_EMAIL", "ZEPP_PASSWORD") if "ZEPP_APP_TOKEN" not in values else ()
    missing = [
        k
        for k in ("HEALTHEE_URL", "HEALTHEE_EMAIL", "HEALTHEE_PASSWORD", *zepp)
        if not values.get(k)
    ]
    if missing:
        raise RefusedError(f"Not installed: {path} has no {', '.join(missing)}.")
    machine.out(f"Using the logins in {path}.")


def _logins(machine: Machine, choice: Choice, user: str, *, fresh: bool) -> None:
    path = choice.env_file
    if path.exists() and not fresh:
        machine.out(f"Using the logins already saved in {path}.")
        machine.out("  To type them again: add --new-logins")
        return
    machine.out("The logins are saved on this server only, in a file only you can read.")
    machine.out("Passwords do not show while you type.")
    values: dict[str, str] = {}
    for name, label, secret in LOGINS:
        values[name] = _asked(machine, label, secret)
    text = env_text(values)
    uid, gid = machine.ids_of(user)
    _owned_dirs(machine, path.parent, uid, gid)
    temp = path.with_name(path.name + ".new")
    temp.unlink(missing_ok=True)
    # Created 600 from the first byte: never readable by anyone else, not even briefly.
    handle = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(handle, "w", encoding="utf-8") as stream:
        stream.write(text)
    machine.chown(temp, uid, gid)
    temp.replace(path)
    machine.out(f"Saved to {path}.")


def _owned_dirs(machine: Machine, folder: Path, uid: int, gid: int) -> None:
    """Make `folder` and any missing parent, each owned by the owner, not by root."""
    missing = [d for d in (folder, *folder.parents) if not d.exists()]
    for directory in reversed(missing):
        directory.mkdir(mode=0o700)
        machine.chown(directory, uid, gid)
    folder.chmod(0o700)


def _asked(machine: Machine, label: str, secret: bool) -> str:
    for _ in range(3):
        value = (machine.ask_secret if secret else machine.ask)(f"{label}: ").strip()
        if value:
            return value
        machine.out("  That was empty. Type it again.")
    raise RefusedError(f"No {label} given. Nothing was installed.")


def _link(machine: Machine) -> None:
    target = REPO / "scripts" / "zepp-nightly"
    if machine.link.is_symlink() or not machine.link.exists():
        machine.link.unlink(missing_ok=True)
        machine.link.symlink_to(target)


def _uninstall(machine: Machine, user: str) -> int:
    machine.run(["systemctl", "disable", "--now", TIMER])
    for name in (SERVICE, TIMER):
        (machine.unit_dir / name).unlink(missing_ok=True)
    machine.run(["systemctl", "daemon-reload"])
    if machine.link.is_symlink():
        machine.link.unlink()
    env_file = machine.home_of(user) / ENV_NAME
    machine.out("The nightly Zepp import is off and removed.")
    if env_file.exists():
        machine.out(f"Your logins are still in {env_file}. Delete it with: rm {env_file}")
    return 0
