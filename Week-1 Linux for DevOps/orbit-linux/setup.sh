#!/usr/bin/env bash
# ==================================================================
#  ORBIT LINUX DOJO  --  world builder
#  Builds a SAFE sandbox you can wreck without fear.
#  Usage:   ./setup.sh           (build it)
#           ./setup.sh --reset   (nuke & rebuild the sandbox only)
# ==================================================================
set -euo pipefail

DOJO="${ORBIT_DOJO:-$HOME/orbit-dojo}"

# --- safety rail: never let DOJO point at something real -----------
case "$DOJO" in
  "$HOME"/orbit-dojo|"$HOME"/orbit-dojo/*) : ;;
  *) echo "Refusing: ORBIT_DOJO must live under \$HOME/orbit-dojo"; exit 1 ;;
esac

if [[ "${1:-}" == "--reset" ]]; then
  echo "Resetting sandbox at $DOJO ..."
  rm -rf "$DOJO"
fi

mkdir -p "$DOJO"
cd "$DOJO"

# --- a fake mini-filesystem to wander around in --------------------
mkdir -p etc var/log srv/orbit/data home/pilot/junk home/pilot/reports \
         bin systemd playground/{crates,airlock,scrap} opt/orbit/{old,new}

# --- fake account files (READ-ONLY format practice, no root needed) -
cat > etc/passwd.sample <<'EOF'
root:x:0:0:root:/root:/bin/bash
pilot:x:1000:1000:Station Pilot:/home/pilot:/bin/bash
mechanic:x:1001:1001:Hull Mechanic:/home/mechanic:/bin/bash
cook:x:1002:1002:Galley Cook:/home/cook:/bin/bash
orbit:x:1100:1100:Orbit Service:/srv/orbit:/usr/sbin/nologin
EOF

cat > etc/group.sample <<'EOF'
crew:x:1000:pilot,mechanic,cook
flightdeck:x:1001:pilot,mechanic
galley:x:1002:cook
docker:x:1003:pilot
sudo:x:27:pilot
EOF

cat > etc/crontab.sample <<'EOF'
# m   h   dom mon dow   command
  0   3   *   *   *     /srv/orbit/backup.sh        # nightly backup
  */15 *  *   *   *     /srv/orbit/healthcheck.sh   # every 15 min
  0   9   1   *   *     /srv/orbit/invoice.sh       # 1st of month, 9am
  30  6   *   *   1-5   /srv/orbit/standup.sh       # weekdays 6:30am
  0   0   *   *   0     /srv/orbit/weekly-wipe.sh   # Sundays midnight
EOF

# --- a systemd unit to read and (later) author ---------------------
cat > systemd/orbit.service <<'EOF'
[Unit]
Description=Orbit Station telemetry daemon
After=network.target

[Service]
Type=simple
ExecStart=/srv/orbit/orbitd --listen 0.0.0.0:9090
Restart=on-failure
User=orbit

[Install]
WantedBy=multi-user.target
EOF

# --- a captured systemctl status (for boxes without live systemd) --
cat > systemd/orbit.status.sample <<'EOF'
* orbit.service - Orbit Station telemetry daemon
     Loaded: loaded (/etc/systemd/system/orbit.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-06-22 03:00:11 UTC; 6h ago
   Main PID: 4242 (orbitd)
      Tasks: 7 (limit: 4915)
     Memory: 38.2M
        CPU: 2.041s
     CGroup: /system.slice/orbit.service
             `-4242 /srv/orbit/orbitd --listen 0.0.0.0:9090
EOF

# --- some props for cp / mv / rm drills ----------------------------
echo "deploy script v1"            > srv/orbit/deploy.sh
echo "listen: 9090"                > srv/orbit/config.yaml
for n in 01 02 03; do echo "telemetry packet $n" > srv/orbit/data/packet_$n.bin; done
echo "pilot's private notes"       > home/pilot/notes.txt
echo "old receipt, delete me"      > home/pilot/junk/receipt.tmp
echo "more junk"                   > home/pilot/junk/cache.tmp
touch playground/scrap/.gitkeep

# --- the orbitd binary stand-in ------------------------------------
cat > bin/orbitctl <<'EOF'
#!/usr/bin/env bash
echo "orbitctl: pretend control plane. args: $*"
EOF
chmod 755 bin/orbitctl

# ==================================================================
#  THE LOGS  --  fuel for the search / text / history drills
# ==================================================================
gen_log() {
  local out="$1"
  : > "$out"
  local ips=(10.0.0.7 10.0.0.7 10.0.0.7 198.51.100.4 203.0.113.9 10.0.0.7 192.0.2.55)
  local paths=(/health /api/telemetry /api/telemetry /login /api/telemetry /metrics /api/burn)
  local codes=(200 200 200 401 500 200 503 200 404)
  for i in $(seq 1 220); do
    local ts; ts=$(printf "2026-06-22 %02d:%02d:%02d" $((i/60%24)) $((i%60)) $(((i*7)%60)))
    local ip=${ips[$((i % ${#ips[@]}))]}
    local path=${paths[$((i % ${#paths[@]}))]}
    local code=${codes[$((i % ${#codes[@]}))]}
    local lvl=INFO
    [[ "$code" == 401 ]] && lvl=WARN
    [[ "$code" == 500 || "$code" == 503 ]] && lvl=ERROR
    echo "$ts $lvl $ip \"GET $path\" $code ${i}ms" >> "$out"
  done
  # a single planted needle, like the vim file
  echo '2026-06-22 13:13:13 ERROR 203.0.113.9 "GET /api/burn" 500 NEEDLE thruster overheat' >> "$out"
}
gen_log var/log/orbit.log

cat > var/log/auth.log <<'EOF'
2026-06-22 02:11:04 sshd[811]: Accepted publickey for pilot from 10.0.0.7 port 51020
2026-06-22 02:44:51 sshd[842]: Failed password for invalid user admin from 203.0.113.9 port 60122
2026-06-22 02:44:55 sshd[842]: Failed password for invalid user admin from 203.0.113.9 port 60124
2026-06-22 02:45:01 sshd[842]: Failed password for invalid user root from 203.0.113.9 port 60130
2026-06-22 05:02:10 sudo: pilot : TTY=pts/0 ; PWD=/srv/orbit ; USER=root ; COMMAND=/usr/bin/systemctl restart orbit
2026-06-22 07:30:00 sshd[990]: Accepted publickey for mechanic from 10.0.0.7 port 51999
EOF

# --- the welcome mat -----------------------------------------------
cat > README_FIRST.txt <<EOF
You have just SSH'd into the Orbit Station server.
You are standing in:  $DOJO

Nothing in here is real. Break it, delete it, chmod it to gibberish.
Rebuild any time with:   ./setup.sh --reset

Open the drills (in another pane or your editor) and work top to bottom.
Start with drills/01_orient.txt
EOF

echo
echo "  Orbit Linux Dojo built at: $DOJO"
echo "  Next:  cd \"$DOJO\"   then open  drills/01_orient.txt"
echo
