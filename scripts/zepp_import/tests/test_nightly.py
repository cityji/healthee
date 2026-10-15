"""The nightly job: the units it writes, the logins file, and the status wording."""

from __future__ import annotations

import stat
import tempfile
import unittest
from collections.abc import Sequence
from pathlib import Path

from zepp_import import nightly
from zepp_import.nightly_units import (
    SERVICE,
    TIMER,
    Choice,
    checked_time,
    checked_zone,
    env_text,
    render,
    schedule_of,
    units,
)
from zepp_import.prompts import load_env_file
from zepp_import.tests.support import sentinel


def _choice(**overrides: object) -> Choice:
    values: dict[str, object] = {
        "user": "nikhil",
        "repo": Path("/home/nikhil/healthee"),
        "env_file": Path("/home/nikhil/.config/healthee-zepp-import/env"),
        "python": "/usr/bin/python3",
        "time": "23:30",
        "zone": "Asia/Kolkata",
        "routes": False,
    }
    values.update(overrides)
    return Choice(**values)  # type: ignore[arg-type]


class UnitsTest(unittest.TestCase):
    def test_the_service_runs_the_importer_unattended_under_a_lock(self) -> None:
        service = units(_choice())[SERVICE]
        exec_line = next(x for x in service.splitlines() if x.startswith("ExecStart="))
        self.assertIn("/usr/bin/flock --nonblock /run/lock/healthee-zepp-import.lock", exec_line)
        self.assertIn("/home/nikhil/healthee/scripts/zepp-import", exec_line)
        self.assertIn("--env-file /home/nikhil/.config/healthee-zepp-import/env", exec_line)
        self.assertIn("--yes --days 3 --no-routes", exec_line)
        self.assertIn("User=nikhil", service)
        self.assertIn("TimeoutStartSec=20min", service)
        self.assertNotIn("{{", service)

    def test_routes_on_drops_the_no_routes_flag(self) -> None:
        service = units(_choice(routes=True))[SERVICE]
        self.assertNotIn("--no-routes", service)
        self.assertIn("--yes --days 3\n", service)

    def test_the_timer_fires_at_the_chosen_time_in_the_chosen_zone(self) -> None:
        timer = units(_choice(time="04:05", zone="Europe/London"))[TIMER]
        self.assertIn("OnCalendar=*-*-* 04:05:00 Europe/London", timer)
        self.assertIn("Persistent=true", timer)

    def test_status_reads_back_what_install_wrote(self) -> None:
        texts = units(_choice(routes=True))
        self.assertEqual(schedule_of(texts[SERVICE], texts[TIMER]), ("23:30 Asia/Kolkata", True))

    def test_a_path_with_a_space_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            units(_choice(repo=Path("/home/a b/healthee")))

    def test_a_placeholder_without_a_value_is_an_error(self) -> None:
        with self.assertRaises(KeyError):
            render("x={{NOPE}}", {})


class ChecksTest(unittest.TestCase):
    def test_times(self) -> None:
        self.assertEqual(checked_time("23:30"), "23:30")
        self.assertEqual(checked_time("7:05"), "07:05")
        for bad in ("24:00", "2330", "11:60", "11:30pm", ""):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                checked_time(bad)

    def test_zones_must_exist_and_cannot_climb_out(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            (Path(root) / "Asia").mkdir()
            (Path(root) / "Asia" / "Kolkata").write_text("")
            self.assertEqual(checked_zone("Asia/Kolkata", Path(root)), "Asia/Kolkata")
            for bad in ("Mars/Base", "../etc/passwd", "Asia/Kolkata 1"):
                with self.subTest(bad=bad), self.assertRaises(ValueError):
                    checked_zone(bad, Path(root))


class EnvTextTest(unittest.TestCase):
    def test_the_importer_reads_back_every_value_exactly(self) -> None:
        values = {
            "HEALTHEE_URL": "healthee.example.com",
            "HEALTHEE_EMAIL": "a@example.com",
            "HEALTHEE_PASSWORD": "'quoted' # with = signs",
            "ZEPP_EMAIL": "b@example.com",
            "ZEPP_PASSWORD": '"both"',
        }
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "env"
            path.write_text(env_text(values))
            path.chmod(0o600)
            self.assertEqual(load_env_file(path), values)

    def test_a_line_break_is_refused(self) -> None:
        values: dict[str, str] = dict.fromkeys(
            ("HEALTHEE_URL", "HEALTHEE_EMAIL", "HEALTHEE_PASSWORD", "ZEPP_EMAIL", "ZEPP_PASSWORD"),
            "x",
        )
        values["ZEPP_PASSWORD"] = "a\nZEPP_EMAIL=evil"
        with self.assertRaises(ValueError):
            env_text(values)


class FakeMachine:
    def __init__(self, root: Path, *, answers: Sequence[str], secrets: Sequence[str]) -> None:
        self.root = root
        self.home = root / "home"
        self.home.mkdir()
        (root / "units").mkdir()
        (root / "zoneinfo" / "Asia").mkdir(parents=True)
        (root / "zoneinfo" / "Asia" / "Kolkata").write_text("")
        self.answers, self.secrets = list(answers), list(secrets)
        self.commands: list[list[str]] = []
        self.said: list[str] = []
        self.asked: list[str] = []
        self.fail: str | None = None
        self.chowned: list[Path] = []
        self.owner = 1000

    def run(self, argv: Sequence[str]) -> tuple[int, str]:
        self.commands.append(list(argv))
        return (1, "") if self.fail and self.fail in argv else (0, "")

    def ask(self, prompt: str) -> str:
        self.asked.append(prompt)
        return self.answers.pop(0)

    def ask_secret(self, prompt: str) -> str:
        self.asked.append(prompt)
        return self.secrets.pop(0)

    def machine(self, *, root: bool = True, sudo_user: str | None = "nikhil") -> nightly.Machine:
        return nightly.Machine(
            is_root=root,
            sudo_user=sudo_user,
            home_of=lambda _: self.home,
            ids_of=lambda _: (1000, 1000),
            run=self.run,
            ask=self.ask,
            ask_secret=self.ask_secret,
            out=self.said.append,
            unit_dir=self.root / "units",
            link=self.root / "zepp-nightly",
            zoneinfo=self.root / "zoneinfo",
            chown=lambda path, *_: self.chowned.append(path),
            owner_of=lambda _path: self.owner,
        )


_ANSWERS = ["healthee.example.com", "a@example.com", "b@example.com"]
_SECRETS = [sentinel("healthee"), sentinel("zepp")]


class InstallTest(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory()
        self.root = Path(self._dir.name)
        self.fake = FakeMachine(self.root, answers=_ANSWERS, secrets=_SECRETS)

    def tearDown(self) -> None:
        self._dir.cleanup()

    def _install(self, *extra: str, **machine: object) -> int:
        argv = ["install", "--time", "23:30", "--no-routes", *extra]
        return nightly.main(argv, self.fake.machine(**machine))  # type: ignore[arg-type]

    def test_install_saves_the_logins_600_writes_units_and_enables_the_timer(self) -> None:
        self.assertEqual(self._install(), 0)
        env = self.fake.home / nightly.ENV_NAME
        self.assertEqual(stat.S_IMODE(env.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(env.parent.stat().st_mode) & 0o077, 0)
        self.assertEqual(load_env_file(env)["ZEPP_PASSWORD"], sentinel("zepp"))
        self.assertTrue((self.root / "units" / SERVICE).is_file())
        self.assertIn(["systemctl", "enable", "--now", TIMER], self.fake.commands)
        self.assertTrue((self.root / "zepp-nightly").is_symlink())
        self.assertIn("Healthee password: ", self.fake.asked)
        said = "\n".join(self.fake.said)
        self.assertIn("23:30 Asia/Kolkata, without routes", said)
        self.assertNotIn(sentinel("zepp"), said)
        self.assertNotIn(sentinel("healthee"), said)

    def test_every_folder_it_creates_is_handed_to_the_owner(self) -> None:
        self._install()
        env = self.fake.home / nightly.ENV_NAME
        self.assertIn(self.fake.home / ".config", self.fake.chowned)
        self.assertIn(env.parent, self.fake.chowned)
        self.assertIn(env.with_name("env.new"), self.fake.chowned)
        self.assertNotIn(self.fake.home, self.fake.chowned)

    def test_a_second_install_keeps_the_saved_logins_without_asking(self) -> None:
        self._install()
        asked = len(self.fake.asked)
        self.assertEqual(self._install(), 0)
        self.assertEqual(len(self.fake.asked), asked)
        self.assertIn("Using the logins already saved", "\n".join(self.fake.said))

    def test_without_sudo_nothing_is_touched(self) -> None:
        self.assertEqual(self._install(root=False), 1)
        self.assertEqual(self.fake.commands, [])
        self.assertEqual(list((self.root / "units").iterdir()), [])

    def test_as_plain_root_it_refuses_to_run_the_import_as_root(self) -> None:
        self.assertEqual(self._install(sudo_user=None), 1)
        self.assertIn("not as root", self.fake.said[-1])

    def test_a_bad_time_is_refused_before_any_question(self) -> None:
        argv = ["install", "--time", "25:00", "--routes"]
        self.assertEqual(nightly.main(argv, self.fake.machine()), 1)
        self.assertEqual(self.fake.asked, [])

    def test_systemd_refusing_is_reported(self) -> None:
        self.fake.fail = "enable"
        self.assertEqual(self._install(), 1)
        self.assertIn("systemd refused", self.fake.said[-1])

    def test_uninstall_removes_the_units_and_keeps_the_logins(self) -> None:
        self._install()
        self.assertEqual(nightly.main(["uninstall"], self.fake.machine()), 0)
        self.assertEqual(list((self.root / "units").iterdir()), [])
        self.assertTrue((self.fake.home / nightly.ENV_NAME).exists())


class OwnEnvFileTest(unittest.TestCase):
    """`--env-file`: a self-hoster's own file, used as it is and never asked for."""

    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory()
        self.root = Path(self._dir.name)
        self.fake = FakeMachine(self.root, answers=[], secrets=[])
        self.env = self.root / "healthee.env"
        self.env.write_text(
            "HEALTHEE_URL=healthee.example.com\nHEALTHEE_EMAIL=a@example.com\n"
            f"HEALTHEE_PASSWORD={sentinel('h')}\nZEPP_EMAIL=b@example.com\n"
            f"ZEPP_PASSWORD={sentinel('z')}\n"
        )
        self.env.chmod(0o600)

    def tearDown(self) -> None:
        self._dir.cleanup()

    def _install(self) -> int:
        argv = ["install", "--time", "23:30", "--no-routes", "--env-file", str(self.env)]
        return nightly.main(argv, self.fake.machine())

    def test_it_is_used_as_it_is_and_nothing_is_asked(self) -> None:
        self.assertEqual(self._install(), 0)
        self.assertEqual(self.fake.asked, [])
        service = (self.root / "units" / SERVICE).read_text()
        self.assertIn(f"--env-file {self.env.resolve()} --yes", service)
        self.assertFalse((self.fake.home / nightly.ENV_NAME).exists())

    def test_a_file_others_can_read_is_refused(self) -> None:
        self.env.chmod(0o644)
        self.assertEqual(self._install(), 1)
        self.assertIn("chmod 600", self.fake.said[-1])
        self.assertEqual(self.fake.commands, [])

    def test_a_file_missing_a_login_is_refused(self) -> None:
        self.env.write_text("HEALTHEE_URL=x\nHEALTHEE_EMAIL=a@example.com\n")
        self.env.chmod(0o600)
        self.assertEqual(self._install(), 1)
        self.assertIn("HEALTHEE_PASSWORD, ZEPP_EMAIL, ZEPP_PASSWORD", self.fake.said[-1])

    def test_someone_elses_file_is_refused(self) -> None:
        self.fake.owner = 0
        self.assertEqual(self._install(), 1)
        self.assertIn("must belong to nikhil", self.fake.said[-1])

    def test_it_cannot_be_combined_with_new_logins(self) -> None:
        argv = ["install", "--time", "23:30", "--routes", "--new-logins", "--env-file", "x"]
        with self.assertRaises(SystemExit):
            nightly.main(argv, self.fake.machine())


if __name__ == "__main__":
    unittest.main()
