==================================================================
 ORBIT LINUX DOJO  --  "Drive the server with your hands, not your hopes"
==================================================================
You have just SSH'd into a derelict station server. You don't know
where you are, who else is aboard, or what's running. Find out.

RULES OF THE GAME
  * Everything happens inside a SANDBOX:  ~/orbit-dojo
    Delete it, chmod it to nonsense, set it on fire. It rebuilds.
  * Type the command. Read the output. THEN read the next line.
  * Don't paste blindly. The point is the muscle memory.
  * Stuck or scared?  ./setup.sh --reset   gives you a fresh station.

SETUP (run once)
  cd orbit-linux-dojo
  ./setup.sh
  cd ~/orbit-dojo          <- you now live here for the file drills

HOW TO PRACTICE
  Keep a drill file open in one pane, a shell in the other.
  Work the drills in order:

    01_orient.txt        Where am I? What is this place?
    02_create_move.txt   Build, copy, haul, and throw away.
    03_users_perms.txt   Who's aboard, who owns what, who's allowed.
    04_systemd_cron.txt  The station's autopilot and its alarm clock.
    05_networking.txt    Talk to the outside. Open and shut the doors.
    06_history.txt       Read the ship's log. Who did what, and when.
    07_logs_text.txt     EXTRA HW: pan for gold in a river of log lines.
    08_processes_signals.txt  Spot, watch, and cull the station wildlife.
    09_packages.txt      Requisition gear without wrecking the shared bay.

SHARED-VM HOUSE RULES  (read this -- it's the whole safety model)
  You log into a COMMON station with your own SSH key and account. You
  own  /home/<you>  and nothing else. The drills are built so that:
    * Everything you BUILD lives in your own ~/orbit-dojo sandbox.
    * You do NOT have sudo, by design -- so you can't touch the box or
      other students even by accident.
    * You can LOOK at the whole station (ps aux, ss, /etc/passwd) but
      only TOUCH your own things. Unix ownership enforces this for free;
      Drill 08 makes you prove it.
    * Anything that needs root (apt install, system services, ufw) is
      shown as a READ / SIMULATE / instructor-demo step, never something
      you run on the shared box. The hands-on versions are per-user
      (systemctl --user, crontab, pip --user, your own container).
  One student can never step into another's shoes. That's not a rule we
  ask you to follow -- it's a wall the kernel holds up. You'll test it.

A FEW NEED REAL TOOLS (network drills especially). The INSTRUCTOR
pre-installs these once on the shared VM (students don't have sudo):
  sudo apt update && sudo apt install -y \
    iproute2 iputils-ping dnsutils netcat-openbsd curl \
    traceroute rsync openssh-client tree
On your OWN laptop/VM, run that yourself.

==================================================================
 Begin with 01_orient.txt . Esc your fear. Hands on the keyboard.
==================================================================
