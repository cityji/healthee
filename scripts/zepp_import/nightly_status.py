"""`zepp-nightly status`: did last night's import work, in a few plain lines.

The facts come from systemd (`systemctl show`) and the run's own output in the journal.
Reading them is behind one `Run` seam so the wording is tested without a systemd.
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass

from zepp_import.nightly_units import SERVICE, TIMER, schedule_of

# argv in, (exit status, stdout) out.
Run = Callable[[Sequence[str]], "tuple[int, str]"]

_RESULTS = {
    "success": "It worked.",
    "exit-code": "It FAILED. What it said:",
    "timeout": "It FAILED: it ran past 20 minutes and was stopped.",
    "signal": "It FAILED: it was killed before it finished.",
}
_SUMMARY_STARTS = ("To write:", "Nothing to import.")


@dataclass(frozen=True)
class Facts:
    installed: bool
    schedule: str
    routes: bool
    started: str  # empty when it never ran
    running: bool
    result: str  # systemd's Result=, such as success or exit-code
    next_run: str
    output: list[str]


def summary(output: Sequence[str], worked: bool) -> list[str]:
    """The lines worth reading from one run: how many it found, then what it did.

    A run that failed before its plan has no summary, so the last paragraph (the
    failure and what to do about it) is shown instead."""
    lines = [line.rstrip() for line in output]
    found = [line for line in lines if line.startswith("Since ")][:1]
    start = next((i for i, line in enumerate(lines) if line.startswith(_SUMMARY_STARTS)), None)
    if start is not None and worked:
        return found + [line for line in lines[start:] if line]
    if not worked:
        blanks = [i for i, line in enumerate(lines) if not line.strip()]
        tail = lines[blanks[-1] + 1 :] if blanks else lines[-6:]
        if not [line for line in tail if line.strip()] and len(blanks) > 1:
            tail = lines[blanks[-2] + 1 : blanks[-1]]
        return found + [line for line in tail if line]
    return found + [line for line in lines if line][-3:]


def report(facts: Facts) -> list[str]:
    if not facts.installed:
        return [
            "The nightly Zepp import is not installed on this server.",
            "  Install it: sudo python3 scripts/zepp-nightly install",
        ]
    routes = "with routes" if facts.routes else "without routes"
    out = [f"Zepp import runs every night at {facts.schedule}, {routes}."]
    if facts.running:
        out.append("It is running right now. Ask again in a minute.")
    elif not facts.started:
        out.append("It has not run yet.")
        out.append("  Run it now: sudo systemctl start healthee-zepp-import")
    else:
        worked = facts.result == "success"
        verdict = _RESULTS.get(facts.result, f"It FAILED ({facts.result}). What it said:")
        out.append(f"Last run: {facts.started}. {verdict}")
        out.extend(f"  {line}" for line in summary(facts.output, worked))
        if not worked:
            out.append("  Full log: journalctl -u healthee-zepp-import -n 80")
    if facts.next_run:
        out.append(f"Next run: {facts.next_run}.")
    return out


def _show(run: Run, unit: str, *props: str) -> dict[str, str]:
    status, text = run(["systemctl", "show", unit, *(f"--property={p}" for p in props)])
    if status != 0:
        return {}
    pairs = (line.partition("=") for line in text.splitlines())
    return {key: value for key, _, value in pairs}


def gather(run: Run, read_unit: Callable[[str], str | None]) -> Facts:
    service_text, timer_text = read_unit(SERVICE), read_unit(TIMER)
    if service_text is None or timer_text is None:
        return Facts(False, "", False, "", False, "", "", [])
    schedule, routes = schedule_of(service_text, timer_text)
    service = _show(run, SERVICE, "Result", "ActiveState", "ExecMainStartTimestamp", "InvocationID")
    timer = _show(run, TIMER, "NextElapseUSecRealtime")
    started = service.get("ExecMainStartTimestamp", "")
    running = service.get("ActiveState") == "activating"
    invocation = service.get("InvocationID", "")
    output: list[str] = []
    if started and invocation:
        status, text = run(
            ["journalctl", "--no-pager", "-o", "cat", f"_SYSTEMD_INVOCATION_ID={invocation}"]
        )
        output = text.splitlines() if status == 0 else []
        if not any(line.strip() for line in output):
            output = ["(this user cannot read the log; try: sudo zepp-nightly status)"]
    return Facts(
        installed=True,
        schedule=schedule,
        routes=routes,
        started=started,
        running=running,
        result=service.get("Result", ""),
        next_run=timer.get("NextElapseUSecRealtime", ""),
        output=output,
    )
