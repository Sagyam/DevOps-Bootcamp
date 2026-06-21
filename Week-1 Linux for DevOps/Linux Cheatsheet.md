# Linux for DevOps — Command Cheat Sheet

A companion reference for the **Linux for DevOps** chapter. Organized the same way as the slides: six days, problem-first. Every entry is *syntax → what it does → a DevOps example*.

> **How to read this:** `placeholders` in angle brackets are yours to fill in. `# comments` explain intent. On the bootcamp devcontainer you also have modern helpers — `eza` (better `ls`), `bat` (better `cat`), `duf` (better `df`), `btop`, `tldr`, and `yq` (mikefarah's Go version). The classic commands below work *everywhere*, which is why we learn them first.

> **Survival reflexes:** `man <cmd>` (full manual) · `<cmd> --help` (quick options) · `tldr <cmd>` (practical examples) · `Ctrl-C` (kill running command) · `Ctrl-R` (search command history) · `q` (quit a pager like `man`/`less`).

---

## Day 1 — Living in the Filesystem

### Orient & navigate

| Command | Does | Example |
|---|---|---|
| `pwd` | Print working directory | `pwd` → `/opt/myapp` |
| `ls -lah` | List: long, all (incl. hidden), human sizes | `ls -lah /var/log` |
| `cd <dir>` | Change directory | `cd /etc/nginx` · `cd -` (jump back) · `cd` (home) |
| `tree -L <n>` | Show directory tree, `n` levels deep | `tree -L 2 /etc/systemd` |
| `date` | Current date/time | `date +%F` → `2026-06-20` (great for log/file naming) |
| `df -h` | Disk free per mount, human-readable | `df -h` — *first check when a deploy fails* |
| `du -sh <dir>` | Total size of a directory | `du -sh /var/log/*` (find the space hog) |

### Create, copy & move

| Command | Does | Example |
|---|---|---|
| `touch <file>` | Create empty file / update timestamp | `touch app.env` |
| `mkdir -p <path>` | Make directory; `-p` creates parents | `mkdir -p /opt/myapp/releases` |
| `cp <src> <dst>` | Copy file; `-r` for directories | `cp config.yml config.yml.bak` |
| `mv <src> <dst>` | Move **or** rename | `mv app-v2 /opt/myapp/current` |
| `rm <file>` | Delete; `-r` recursive, `-f` force | `rm -rf /tmp/build` ⚠️ *no undo* |
| `ln -s <tgt> <link>` | Symbolic link (atomic deploys) | `ln -sfn releases/v2 current` |

### Filesystem hierarchy (where things live)

`/etc` config · `/var/log` logs · `/var/lib` service data · `/opt` & `/srv` your apps · `/usr/bin` binaries · `/home` users · `/tmp` scratch · `/proc` & `/sys` live kernel state.

### vim — on every server

Modes: **Normal** (navigate), **Insert** (`i` to type), **Command** (`:`).

| Keys | Does |
|---|---|
| `i` / `Esc` | Enter insert mode / back to normal |
| `:w` / `:q` / `:wq` | Write / quit / write+quit |
| `:q!` | Quit, discard changes (**the escape hatch**) |
| `dd` / `yy` / `p` | Delete line / yank line / paste |
| `/text` then `n` | Search forward, next match |
| `:%s/old/new/g` | Replace all in file |

#### Search with your fingers, not your eyes

Don't scroll and scan with your eyes, then arrow over one cell at a time. **Name where you want to go** and let vim jump there. These motions move you by *meaning* — a word, a character, a line — not one keystroke per column.

| Keys | Jumps to |
|---|---|
| `/pat` · `?pat` | First match forward / backward (`Enter` to land) |
| `n` / `N` | Repeat last search, same / opposite direction |
| `*` / `#` | Search the word **under the cursor**, fwd / back |
| `f{c}` / `F{c}` | Onto the next / prev `{c}` on this line |
| `t{c}` / `T{c}` | Up to (just before) the next / prev `{c}` |
| `;` / `,` | Repeat the last `f`/`t`/`F`/`T`, same / reverse |
| `w` · `b` · `e` | Word: next start / prev start / end of word |
| `0` · `^` · `$` | Line: start / first non-blank / end |
| `gg` · `G` · `:42` | File top / file end / go to line 42 |
| `%` | Jump to the matching `()` `{}` `[]` |
| `Ctrl-d` / `Ctrl-u` | Half-page down / up (keep your bearings) |

**The payoff — aim, then act.** Every motion composes with an operator, so a search *becomes* an edit: `d/ERROR` deletes up to the next "ERROR", `ci"` changes inside the quotes, `ct;` changes up to the next `;`, `y}` yanks to the next blank line. Once you can *aim*, editing collapses to **operator + target**.

### nano — the friendly fallback

`nano <file>` then edit directly. `^` means **Ctrl**. `^O` save (write Out) · `^X` exit · `^W` search · `^K` cut line · `^U` paste.

---

## Day 2 — Users, Groups & Permissions

### Users & groups

| Command | Does | Example |
|---|---|---|
| `whoami` / `id` | Who am I / my uid, gid, groups | `id deploy` |
| `sudo <cmd>` | Run one command as root | `sudo systemctl restart nginx` |
| `useradd -m -s /bin/bash <u>` | Create user with home + shell | `sudo useradd -m -s /bin/bash deploy` |
| `useradd -r -s /usr/sbin/nologin <u>` | Create **service** account (no login) | `sudo useradd -r -s /usr/sbin/nologin myapp` |
| `passwd <u>` | Set/change password | `sudo passwd deploy` |
| `usermod -aG <grp> <u>` | Add user to group (**`-aG`, not `-G`**) | `sudo usermod -aG docker deploy` |
| `groupadd <grp>` | Create a group | `sudo groupadd deployers` |
| `userdel -r <u>` | Delete user + home | `sudo userdel -r olduser` |

> ⚠️ **The classic trap:** `usermod -G docker deploy` *replaces* all of `deploy`'s groups. Always use `-aG` (append). Re-login for new groups to take effect.

### Ownership & permissions

Read `ls -l` output: `-rwxr-xr--  1 deploy www-data  …`
→ type · **owner** rwx · **group** rwx · **other** rwx · owner · group.

| Bit | Value | On a file | On a directory |
|---|---|---|---|
| `r` | 4 | read contents | list entries |
| `w` | 2 | modify | add/remove entries |
| `x` | 1 | execute | **enter (`cd` into)** |

| Command | Does | Example |
|---|---|---|
| `chmod <mode> <f>` | Change permissions (numeric) | `chmod 644 config.yml` (rw-r--r--) |
| `chmod +x <f>` | Make executable (symbolic) | `chmod +x deploy.sh` |
| `chmod 600 <f>` | Owner-only (keys!) | `chmod 600 ~/.ssh/id_ed25519` |
| `chmod -R <mode> <d>` | Recursive | `chmod -R 755 /var/www` |
| `chown <u>:<g> <f>` | Change owner:group | `sudo chown -R www-data:www-data /var/www` |
| `umask` | Default-permission mask | `umask 022` → new files 644, dirs 755 |

Common modes: **755** dirs/scripts · **644** normal files · **600** secrets/keys · **700** private dirs.

---

## Day 3 — Text Processing & Filtering

> The Unix philosophy: small tools, piped. Build the answer by chaining. `cmd1 | cmd2 | cmd3`. `>` redirects stdout to a file (overwrite), `>>` appends, `2>` redirects errors.

### grep — find matching lines

| Form | Does |
|---|---|
| `grep "pattern" file` | Print matching lines |
| `grep -i` | Case-insensitive |
| `grep -r "txt" dir/` | Recursive search in a tree |
| `grep -v "pattern"` | **Invert** — lines that *don't* match |
| `grep -c "pattern"` | Count matches |
| `grep -E "a|b"` | Extended regex (OR) |

```bash
grep -i error /var/log/syslog                 # find errors
journalctl -u nginx | grep -E "40[0-9]|50[0-9]" # 4xx/5xx in service logs
ps aux | grep -v grep | grep node             # find node procs, drop the grep itself
```

### cut, sort, uniq — columns & counting

```bash
cut -d: -f1 /etc/passwd            # field 1, ':'-delimited → usernames
cut -d, -f2,5 data.csv             # columns 2 and 5 of a CSV
sort access.log | uniq -c | sort -rn | head   # top repeated lines
awk '{print $1}' access.log | sort | uniq -c | sort -rn  # top client IPs
```

### sed — edit a stream

| Form | Does |
|---|---|
| `sed 's/old/new/'` | Replace first match per line |
| `sed 's/old/new/g'` | Replace **all** matches per line |
| `sed -i 's/old/new/g' file` | Edit file **in place** |
| `sed -n '5,10p' file` | Print only lines 5–10 |
| `sed '/^#/d'` | Delete comment lines |

```bash
sed -i 's/DEBUG=true/DEBUG=false/' app.env    # flip a config flag in CI
sed -i.bak 's/8080/9090/g' config.yml         # edit, keep a .bak backup
```

### awk — field-aware processing

```bash
awk '{print $1, $4}' access.log               # columns 1 and 4
awk -F: '{print $1}' /etc/passwd              # custom delimiter
awk '$3 > 1000 {print $1}' report.txt         # rows where col3 > 1000
awk '{sum+=$5} END {print sum}' sizes.txt      # sum a column
df -h | awk '$5+0 > 80 {print $6, $5}'         # mounts over 80% full
```

### jq — query & transform JSON

```bash
curl -s api/status | jq '.'                    # pretty-print
jq '.items[].name' data.json                  # field from each array item
jq -r '.token' creds.json                     # raw output (no quotes)
kubectl get pods -o json | jq '.items[].metadata.name'
jq '.users | map(select(.active)) | length'   # count active users
```

### yq — jq, but for YAML

> The bootcamp uses **mikefarah's Go `yq`** (syntax mirrors `jq`).

```bash
yq '.services.web.image' docker-compose.yml    # read a value
yq -i '.replicas = 3' deployment.yaml          # edit in place
yq '.spec.containers[].image' pod.yaml
yq -o=json '.' config.yaml                     # convert YAML → JSON
```

---

## Day 4 — Administering the System

### apt — package management (Ubuntu/Debian)

| Command | Does |
|---|---|
| `sudo apt update` | Refresh package index (**do first**) |
| `sudo apt upgrade` | Install available updates |
| `sudo apt install -y <pkg>` | Install (`-y` auto-confirms) |
| `sudo apt remove <pkg>` | Remove (keeps config) |
| `sudo apt purge <pkg>` | Remove **+ config** |
| `apt search <kw>` | Find a package |
| `apt show <pkg>` | Package details |
| `apt list --installed` | What's installed |

```bash
sudo apt update && sudo apt -y upgrade         # canonical first two lines on a fresh box
sudo apt install -y nginx jq curl
```

### Process monitoring — ps & btop

```bash
ps aux                      # every process: user, %CPU, %MEM, command
ps aux --sort=-%mem | head  # top memory consumers
ps -u postgres              # processes for one user
pgrep -a nginx              # PIDs matching a name
kill <pid>                  # ask to stop (SIGTERM)
kill -9 <pid>               # force kill (SIGKILL — last resort)
btop                        # live interactive dashboard (q to quit)
```

### systemd & systemctl — managing services

systemd is the init system (PID 1) that starts and supervises services.

| Command | Does |
|---|---|
| `systemctl status <svc>` | Is it running? recent logs |
| `sudo systemctl start/stop/restart <svc>` | Control it now |
| `sudo systemctl reload <svc>` | Re-read config, no downtime |
| `sudo systemctl enable --now <svc>` | Start now **and** on boot |
| `sudo systemctl disable <svc>` | Don't start on boot |
| `systemctl is-active <svc>` | Script-friendly check |
| `systemctl list-units --type=service` | All services |

```bash
sudo systemctl restart myapp && systemctl status myapp   # deploy then confirm
```

### Creating your own service — `/etc/systemd/system/myapp.service`

```ini
[Unit]
Description=My API
After=network.target

[Service]
User=myapp
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/run
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload          # re-read unit files after editing
sudo systemctl enable --now myapp     # start + run on boot
systemctl status myapp                # confirm
```

> Three sections: **[Unit]** what & ordering · **[Service]** how to run (incl. `Restart`) · **[Install]** how it's enabled. Always `daemon-reload` after editing a unit.

### journalctl — reading the logs

```bash
journalctl -u myapp              # logs for one service
journalctl -u myapp -f           # follow live (like tail -f)
journalctl -u myapp -e           # jump to end
journalctl -u myapp --since "1 hour ago"
journalctl -p err -b             # errors only, this boot
journalctl -u myapp -n 50 --no-pager   # last 50 lines, script-friendly
```

### cron — classic scheduled jobs

`crontab -e` to edit. Five time fields, then the command:

```
┌─ minute (0-59)
│ ┌─ hour (0-23)
│ │ ┌─ day of month (1-31)
│ │ │ ┌─ month (1-12)
│ │ │ │ ┌─ day of week (0-6, Sun=0)
* * * * *  command
```

```bash
0 2 * * *      /opt/backup.sh                 # daily at 02:00
*/5 * * * *    /opt/healthcheck.sh            # every 5 minutes
0 */6 * * *    /usr/bin/find /tmp -mtime +7 -delete   # cleanup every 6h
```

`crontab -l` list · `crontab -r` remove all. Tip: redirect output → `>> /var/log/job.log 2>&1`.

### systemd timers — the modern scheduler

`backup.timer` + `backup.service` (the timer triggers the service).

```ini
# backup.timer
[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true          # catch up if the machine was off

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl enable --now backup.timer
systemctl list-timers            # see next run times
```

Why over cron: real logging via journald, dependency ordering, and catch-up for missed runs.

---

## Day 5 — Networking, Remote & Transfer

### ip — addresses, routes, links (replaces `ifconfig`)

```bash
ip a                  # all addresses (a = address)
ip -br a              # brief, readable summary
ip r                  # routing table (r = route); find the default gateway
ip link               # network interfaces up/down
```

### Reachability, DNS & open ports

```bash
ping -c 4 8.8.8.8           # is the host reachable? (-c = count, then stop)
dig example.com             # full DNS lookup
dig +short example.com      # just the IP
dig example.com MX          # mail records
ss -tulpn                   # open ports: TCP/UDP, listening, PID (replaces netstat)
ss -tulpn | grep :443       # is anything listening on 443?
```

> **Triage order when "the site is down":** `ping` (network up?) → `dig` (DNS resolving?) → `ss` (is anything even listening on the port?).

### ssh — remote login

```bash
ssh user@host                       # log in
ssh -i ~/.ssh/key user@host         # use a specific private key
ssh user@host 'systemctl status nginx'   # run ONE remote command
ssh-keygen -t ed25519               # make a modern keypair
ssh-copy-id user@host               # install your PUBLIC key on the server
scp file user@host:/path            # copy a file over SSH
scp -r dir/ user@host:/path         # copy a directory
```

`~/.ssh/config` turns a long command into `ssh prod`:

```
Host prod
    HostName 203.0.113.42
    User deploy
    IdentityFile ~/.ssh/id_ed25519
```

> Keys, not passwords: public key on the server, **private key secret (`chmod 600`)**, nothing to phish or brute-force.

### ufw — the simple firewall

```bash
sudo ufw allow 22/tcp        # ALLOW SSH *before* enabling, or you lock yourself out
sudo ufw allow 443/tcp
sudo ufw enable              # turn it on
sudo ufw status numbered     # review rules
sudo ufw delete <num>        # remove a rule
sudo ufw default deny incoming
```

> ⚠️ Always `allow 22` (or your SSH port) **before** `ufw enable` on a remote box.

### Downloading files — wget & curl

```bash
curl -O https://host/file.tar.gz        # download, keep remote name
curl -fsSL https://host/script | less   # inspect before running (never pipe blind to bash)
curl -s api/health | jq .               # call an API, parse JSON
curl -X POST -d '{"k":"v"}' -H "Content-Type: application/json" api/
wget https://host/file.tar.gz           # simple download
wget -r -np https://host/dir/           # recursive mirror
```

> `curl` = API calls & scripting (talks many protocols). `wget` = simple/recursive file fetches. **Never** `curl … | sudo bash` without reading the script first.

---

## Day 6 — Scripting, Archiving & Storage

### Bash scripting basics

```bash
#!/usr/bin/env bash
set -euo pipefail        # e=exit on error, u=error on unset var, pipefail=catch pipe errors

NAME="deploy"            # variable (NO spaces around =)
COUNT=5
echo "Hello $NAME"       # use with $
echo "${NAME}_v2"        # braces when adjacent to text
```

**Command substitution** — capture output into a variable:

```bash
NOW=$(date +%F)
FILES=$(ls *.log | wc -l)
echo "$FILES logs on $NOW"
```

**Exit codes** — `$?` is the last command's status (0 = success):

```bash
systemctl is-active --quiet nginx && echo "up" || echo "DOWN"
```

**Conditionals** — prefer `[[ ... ]]`:

```bash
if [[ -f "$CONFIG" ]]; then echo "config exists"; fi
if [[ -z "$1" ]]; then echo "missing arg"; exit 1; fi
if [[ "$ENV" == "prod" ]]; then ...; fi
```

| Test | True when |
|---|---|
| `-f file` | file exists |
| `-d dir` | directory exists |
| `-z str` | string is empty |
| `-n str` | string is non-empty |
| `$a -eq $b` | numbers equal (`-gt -lt -ge -le`) |

**Loops:**

```bash
for svc in nginx myapp redis; do systemctl restart "$svc"; done
for f in /var/log/*.log; do gzip "$f"; done
for i in {1..5}; do echo "attempt $i"; done
while read -r line; do echo "$line"; done < hosts.txt
until ping -c1 host &>/dev/null; do sleep 2; done   # retry until reachable
```

### Putting it together — `healthcheck.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICES=(nginx myapp redis)
FAIL=0

for svc in "${SERVICES[@]}"; do
  if systemctl is-active --quiet "$svc"; then
    echo "OK   $svc"
  else
    echo "DOWN $svc" >&2
    FAIL=$((FAIL + 1))
  fi
done

[[ "$FAIL" -eq 0 ]] && echo "all healthy" || exit 1
```

> Loop (D6) + `systemctl is-active` (D4) + conditional (D6) + stderr (D3) + non-zero exit. Schedule it with a **systemd timer** (D4) and you've built monitoring from primitives.

### Compress & archive

| Command | Does |
|---|---|
| `tar -czf out.tar.gz dir/` | **C**reate **z**gzip **f**ile (bundle + compress) |
| `tar -xzf out.tar.gz` | E**x**tract a `.tar.gz` |
| `tar -tzf out.tar.gz` | Lis**t** contents without extracting |
| `tar -xzf x.tar.gz -C /dst` | Extract into a target dir |
| `gzip file` / `gunzip file.gz` | Compress / decompress a single file |
| `zip -r out.zip dir/` | Create a `.zip` (cross-platform) |
| `unzip out.zip` | Extract a `.zip` |

```bash
tar -czf "app-$(date +%F).tar.gz" /opt/myapp    # timestamped release bundle
ssh user@host 'tar -czf - /var/log' > logs.tar.gz   # stream a remote archive home
```

> Mnemonic: **tar -czf** = **C**reate **Z**ipped **F**ile · **tar -xzf** = e**X**tract **Z**ipped **F**ile.

### Storage with LVM

Stack: **PV** (physical disks) → pooled into a **VG** (volume group) → carved into **LV**s (what you format & mount). The point: grow a volume *live* by adding a disk — no reformat, no downtime.

```bash
# create
sudo pvcreate /dev/sdb                 # 1. disk → physical volume
sudo vgcreate data /dev/sdb            # 2. pool into a volume group
sudo lvcreate -L 20G -n vol1 data      # 3. carve a logical volume
sudo mkfs.ext4 /dev/data/vol1          # 4. format
sudo mount /dev/data/vol1 /data        # 5. mount

# grow when it fills
sudo vgextend data /dev/sdc            # add another disk to the pool
sudo lvextend -L +10G -r /dev/data/vol1   # -r also resizes the filesystem

# inspect
sudo pvs    # physical volumes
sudo vgs    # volume groups
sudo lvs    # logical volumes
```

> The magic flag is `lvextend -r` — it extends the LV **and** the filesystem in one step, while the system is live.

---

## Quick troubleshooting recipes

| Symptom | First moves |
|---|---|
| "Disk full" | `df -h` → `du -sh /var/* \| sort -h` → find & clear the hog |
| "Permission denied" | `ls -l <file>` → read rwx → `chmod`/`chown` to fix |
| "Service won't start" | `systemctl status <svc>` → `journalctl -u <svc> -e` |
| "Can't reach the site" | `ping` → `dig` → `ss -tulpn \| grep <port>` |
| "What's eating CPU/RAM?" | `btop` or `ps aux --sort=-%cpu \| head` |
| "Config flag in many files" | `grep -rl "flag" .` → `sed -i 's/.../.../g'` |
| "Scheduled job didn't run" | `systemctl list-timers` / check `crontab -l` + job log |

---

*Companion to the Linux for DevOps slide deck · Instructor: Sagyam Thapa*