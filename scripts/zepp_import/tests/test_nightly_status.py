"""`zepp-nightly status`: the wording of a good night, a bad night, and no night."""

from __future__ import annotations

import unittest
from collections.abc import Sequence

from zepp_import import nightly_status
from zepp_import.nightly_units import SERVICE, units
from zepp_import.tests.test_nightly import _choice

_RUN = [
    "Healthee: healthee.example.com",
    "  signed in",
    "",
    "Since 08 Oct 2026 (Asia/Kolkata): 4 Zepp workouts",
    "  10 Oct 07:00  Outdoor run",
    "    workout: import",
    "",
    "To write: 1 workout, 0 routes.",
    "",
    "  1 stored, 1 day recalculated",
    "",
    "Done: 1 workout stored.",
    "They show in the Healthee app when it next loads.",
]
_FAILED = [
    "Healthee: healthee.example.com",
    "",
    "Zepp refused the sign-in (HTTP 429).",
    "  Wait an hour and run it again.",
]


def _facts(**overrides: object) -> nightly_status.Facts:
    values: dict[str, object] = {
        "installed": True,
        "schedule": "23:30 Asia/Kolkata",
        "routes": False,
        "started": "Sat 2026-10-10 23:31:02 IST",
        "running": False,
        "result": "success",
        "next_run": "Sun 2026-10-11 23:30:00 IST",
        "output": _RUN,
    }
    values.update(overrides)
    return nightly_status.Facts(**values)  # type: ignore[arg-type]


class StatusTest(unittest.TestCase):
    def test_a_good_night_says_it_worked_and_what_it_stored(self) -> None:
        text = "\n".join(nightly_status.report(_facts()))
        self.assertIn("Last run: Sat 2026-10-10 23:31:02 IST. It worked.", text)
        self.assertIn("Since 08 Oct 2026 (Asia/Kolkata): 4 Zepp workouts", text)
        self.assertIn("Done: 1 workout stored.", text)
        self.assertNotIn("Outdoor run", text)
        self.assertIn("Next run: Sun 2026-10-11 23:30:00 IST.", text)

    def test_a_failed_night_says_so_and_shows_why(self) -> None:
        text = "\n".join(nightly_status.report(_facts(result="exit-code", output=_FAILED)))
        self.assertIn("It FAILED", text)
        self.assertIn("Zepp refused the sign-in (HTTP 429).", text)
        self.assertIn("Wait an hour", text)
        self.assertIn("journalctl -u healthee-zepp-import", text)

    def test_utc_times_are_shown_in_the_chosen_zone(self) -> None:
        facts = _facts(
            started="Sun 2026-10-11 18:01:30 UTC", next_run="Mon 2026-10-12 17:58:02 UTC"
        )
        text = "\n".join(nightly_status.report(facts))
        self.assertIn("Last run: Sun 11 Oct, 23:31. It worked.", text)
        self.assertIn("Next run: Mon 12 Oct, 23:28.", text)

    def test_a_time_in_another_form_is_shown_as_it_came(self) -> None:
        self.assertEqual(
            nightly_status.local_time("Sun 2026-10-11 23:31:30 IST", "23:30 Asia/Kolkata"),
            "Sun 2026-10-11 23:31:30 IST",
        )
        self.assertEqual(
            nightly_status.local_time("Sun 2026-10-11 18:01:30 UTC", "23:30 Mars/Base"),
            "Sun 2026-10-11 18:01:30 UTC",
        )

    def test_never_ran_and_not_installed(self) -> None:
        self.assertIn("has not run yet", "\n".join(nightly_status.report(_facts(started=""))))
        absent = nightly_status.report(_facts(installed=False))
        self.assertIn("not installed", absent[0])

    def test_gather_reads_systemd_and_this_runs_journal(self) -> None:
        texts = units(_choice())
        calls: list[list[str]] = []

        def run(argv: Sequence[str]) -> tuple[int, str]:
            calls.append(list(argv))
            if argv[0] == "journalctl":
                return 0, "\n".join(_RUN)
            if SERVICE in argv:
                return 0, (
                    "Result=success\nActiveState=inactive\n"
                    "ExecMainStartTimestamp=Sat 2026-10-10 23:31:02 IST\nInvocationID=abc123\n"
                )
            return 0, "NextElapseUSecRealtime=Sun 2026-10-11 23:30:00 IST\n"

        facts = nightly_status.gather(run, texts.get)
        self.assertEqual(facts.result, "success")
        self.assertFalse(facts.routes)
        self.assertIn("_SYSTEMD_INVOCATION_ID=abc123", calls[-1])
        self.assertEqual(facts.output, _RUN)

    def test_an_unreadable_journal_is_said_not_hidden(self) -> None:
        texts = units(_choice())

        def run(argv: Sequence[str]) -> tuple[int, str]:
            if argv[0] == "journalctl":
                return 0, ""
            return 0, "ExecMainStartTimestamp=Sat\nInvocationID=x\nResult=success\n"

        facts = nightly_status.gather(run, texts.get)
        self.assertIn("cannot read the log", "\n".join(nightly_status.report(facts)))


if __name__ == "__main__":
    unittest.main()
