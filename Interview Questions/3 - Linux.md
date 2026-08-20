# Linux Fundamentals

## 1. Linux Architecture & File System

### Q1: Explain the Linux File System Hierarchy and the purpose of key directories.
* **Answer:**
  * `/etc`: System-wide configuration files (e.g., `/etc/nginx/`, `/etc/passwd`, `/etc/fstab`, `/etc/hosts`).
  * `/var`: Variable data that grows over time (e.g., `/var/log` for system/service logs, `/var/lib/docker`).
  * `/proc`: Virtual pseudo-filesystem providing an interface to kernel data structures and running process states (e.g., `/proc/cpuinfo`, `/proc/meminfo`, `/proc/<PID>/`).
  * `/dev`: Device nodes representing hardware or virtual devices (e.g., `/dev/sda`, `/dev/null`, `/dev/urandom`).
  * `/opt`: Optional add-on third-party software packages.
  * `/tmp`: Temporary files, often cleared on reboot.
  * `/home` and `/root`: User personal home directories and root superuser home.

---

### Q2: What is an Inode? What happens if a Linux server runs out of Inodes while disk space is still available?
* **Answer:**
  * An **Inode (Index Node)** is a data structure on Linux filesystems that stores metadata about a file (file size, permissions, owner, group, timestamps, pointers to disk data blocks), **except** the file name and actual file data content.
  * **Exhaustion Scenario:** If a filesystem creates millions of tiny files (e.g., un-rotated session files, cache, or emails in `/var/spool`), all allocated Inodes will be consumed.
  * **Result:** The system will return `No space left on device` when creating a new file, even if `df -h` shows plenty of available disk storage.
  * **Diagnosis & Fix:** Check with `df -i` to view Inode utilization. Clean up obsolete small files or directories using `find /path -type f -delete`.

---

### Q3: What is the difference between a Hard Link and a Soft (Symbolic) Link?
* **Answer:**
  | Characteristic | Hard Link | Soft Link (`ln -s`) |
  | :--- | :--- | :--- |
  | **Inode Number** | Shares the exact same Inode number as the target. | Has its own distinct Inode number. |
  | **Target Deletion** | File data remains accessible until all hard links are deleted. | Becomes a broken ("dangling") link. |
  | **Cross-Filesystem** | Cannot cross different filesystems or partitions. | Can link across different filesystems/mounts. |
  | **Directories** | Cannot link to directories (to avoid loops). | Can link to both files and directories. |

---

## 2. Permissions, Users & Security

### Q4: Explain Linux file permissions `rwxr-xr--` and how to calculate numeric permissions.
* **Answer:**
  * Permissions are split into 3 groups of 3 characters: `User (Owner) | Group | Others`.
    - `r` (Read) = 4
    - `w` (Write) = 2
    - `x` (Execute) = 1
  * For `rwxr-xr--`:
    - User: `rwx` = 4 + 2 + 1 = **7**
    - Group: `r-x` = 4 + 0 + 1 = **5**
    - Others: `r--` = 4 + 0 + 0 = **4**
    - Numeric value: **754**
  * Modifying command: `chmod 754 script.sh` or `chmod u=rwx,g=rx,o=r script.sh`.
  * Ownership modification: `chown user:group filename`.

---

### Q5: What are Special Permissions in Linux: SUID, SGID, and Sticky Bit?
* **Answer:**
  * **SUID (Set User ID - `chmod 4755` / `u+s`):** When executed, the file runs with the permissions of the file owner rather than the user executing it (e.g., `/usr/bin/passwd` needs root privileges to write to `/etc/shadow`).
  * **SGID (Set Group ID - `chmod 2755` / `g+s`):** On directories, new files created inside inherit the group ownership of the parent directory rather than the creator's primary group.
  * **Sticky Bit (`chmod 1777` / `+t`):** Used on shared writable directories (e.g., `/tmp`). Only the file owner or root can delete or rename files within that directory, preventing users from deleting each other's files.

---

## 3. Processes, Systemd & Resource Monitoring

### Q6: What is the difference between a Zombie process and an Orphan process?
* **Answer:**
  * **Orphan Process:** A parent process terminates before its child process finishes. The orphaned child is adopted by the system initialization process (`init` or `systemd`, PID 1), which reaps its exit status when it finishes. Orphan processes do not harm the system.
  * **Zombie Process (Defunct):** A process that has completed execution via `exit()`, but its parent process has not yet read its exit status via the `wait()` system call. It retains an entry in the process table (consuming a PID).
  * **How to kill a Zombie:** You cannot kill a zombie with `kill -9` because it is already dead. You must kill its parent process so the zombie is adopted by PID 1 and cleaned up.

---

### Q7: Explain standard Linux signals: `SIGTERM (15)`, `SIGKILL (9)`, and `SIGHUP (1)`.
* **Answer:**
  * **`SIGTERM (15)`:** Graceful termination request. The process can catch, block, or handle this signal, allowing it to close database connections, finish ongoing transactions, and clean up temporary files before exiting.
  * **`SIGKILL (9)`:** Immediate, unconditional process termination handled directly by the kernel. The process cannot intercept, catch, or ignore it. Should only be used when `SIGTERM` fails to stop a hung process.
  * **`SIGHUP (1)`:** Hangup signal. Often used to instruct daemon processes (e.g., NGINX, Apache) to reload configuration files without stopping active worker connections.

---

### Q8: How do you check system performance (CPU, Memory, Disk I/O, Network)? List the key commands.
* **Answer:**
  * **CPU & Overall Load:**
    - `top` / `htop`: Interactive real-time process and CPU core utilization.
    - `uptime`: System running time and Load Averages (1, 5, 15 minutes).
  * **Memory:**
    - `free -h`: Displays total, used, free, shared, and available RAM and Swap space.
    - `vmstat 1`: Virtual memory, paging, and CPU activity per second.
  * **Disk & Storage:**
    - `df -h`: Filesystem disk space usage in human-readable format.
    - `du -sh /var/*`: Directory-level disk consumption.
    - `iostat -xz 1`: Detailed disk I/O metrics (%util, read/write ops, await latency).
  * **Networking & Sockets:**
    - `ss -tulpn` (or `netstat -tulpn`): Active listening TCP/UDP ports and associated process names.
    - `ip a` / `ip route`: Network interface IPs and routing table.
    - `ping`, `traceroute` / `mtr`, `curl -Iv`: Connectivity and latency diagnostics.
  * **Open Files & Processes:**
    - `lsof -i :80`: Find which process is occupying port 80.
    - `ps aux | grep java`: Search active Java processes.

---

## 4. Text Processing & Shell Scripting

### Q9: Explain `grep`, `awk`, and `sed` with common practical examples.
* **Answer:**
  * **`grep` (Search):** Filters lines matching regular expressions.
    ```bash
    # Find all 500 error codes in Nginx access logs
    grep " 500 " /var/log/nginx/access.log
    ```
  * **`awk` (Column processing & reporting):**
    ```bash
    # Extract client IP addresses (1st column) and count unique visitors
    awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr
    ```
  * **`sed` (Stream editor / text replacement):**
    ```bash
    # Replace all occurrences of 'localhost' with '0.0.0.0' in a config file
    sed -i 's/localhost/0.0.0.0/g' app.conf
    ```

---

### Q10: What do `set -e`, `set -u`, and `set -o pipefail` do in Bash scripts?
* **Answer:**
  These flags are best practice at the start of production Bash scripts (`set -euo pipefail`):
  * `set -e`: Causes the script to exit immediately if any command exits with a non-zero (error) status.
  * `set -u`: Treats unset/uninitialized variables as an error and exits immediately (prevents accidental disasters like `rm -rf /${UNSET_VAR}`).
  * `set -o pipefail`: By default, a pipeline (e.g., `cmd1 | cmd2`) only returns the exit status of the *last* command (`cmd2`). With `pipefail`, the pipeline returns failure if *any* command in the chain fails.

---

### Q11: Explain standard streams and redirection (`>`, `>>`, `2>&1`, `/dev/null`).
* **Answer:**
  * `stdin` (File Descriptor 0): Standard input.
  * `stdout` (File Descriptor 1): Standard output.
  * `stderr` (File Descriptor 2): Standard error.
  * `>` overwrites `stdout` to a file; `>>` appends `stdout` to a file.
  * `2>&1` redirects standard error (`2`) to standard output (`1`).
  * `command > /dev/null 2>&1`: Runs a command silently, discarding both standard output and error messages into `/dev/null` (the bit bucket).