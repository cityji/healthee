# Nightly Zepp import

Runs `scripts/zepp-import` once a night on a Linux server with systemd, so workouts
recorded in the Zepp app reach Healthee without anyone at the keyboard.

## Install (once, over ssh)

From the repository checkout on the server:

```sh
sudo python3 scripts/zepp-nightly install --time 23:30 --no-routes
```

It asks for the Healthee address, email and password, and the Zepp email and password.
Passwords do not show while typed. They are saved in
`~/.config/healthee-zepp-import/env`, mode 600, owned by you, and nowhere else. Then it
installs `healthee-zepp-import.service` and `.timer` into `/etc/systemd/system` and turns
the timer on. The import runs as you, never as root.

* `--time HH:MM` and `--zone` (default `Asia/Kolkata`): when it runs.
* `--routes` or `--no-routes`: one is required. Routes feed the fitness estimate and so
  biological age; read "What changes in Healthee" in `scripts/zepp_import/README.md`
  before choosing. There is no undo for an import.
* `--new-logins`: type the logins again. Without it a second install keeps them.
* `--env-file FILE`: use logins you already keep in a file of your own instead of being
  asked: the five names below, one `NAME=value` per line, owned by you and `chmod 600`.
  Nothing is asked and nothing is copied; the timer reads that file each night.

  ```
  HEALTHEE_URL=healthee.example.com
  HEALTHEE_EMAIL=you@example.com
  HEALTHEE_PASSWORD=...
  ZEPP_EMAIL=you@example.com
  ZEPP_PASSWORD=...
  ```

Each run looks back 3 days (`--days 3`) for workouts, so a missed night is caught up,
and checks every Zepp weigh-in against Healthee. A run is stopped
after 20 minutes, and a lock keeps two runs from overlapping. A server that was off at
the time runs it once when it is back.

## Did last night work?

```sh
zepp-nightly status
```

It says when the last run was, whether it worked, how many Zepp workouts it found and
what it stored, or, when it failed, what the importer said. The full log is
`journalctl -u healthee-zepp-import`. Run it now: `sudo systemctl start healthee-zepp-import`.

## Remove

```sh
sudo zepp-nightly uninstall
```

The timer and units go. The logins file stays until you delete it; the command prints
its path.
