# Containers

## 1. Fundamentals & Docker Architecture

### Q1: What is a Container, and how does it differ from a Virtual Machine (VM)?
* **Answer:**
  * **Virtual Machine (VM):**
    - Virtualizes hardware via a Hypervisor (Type 1 or Type 2).
    - Each VM runs a full guest operating system with its own kernel, binaries, and virtual device drivers.
    - Slower startup (minutes), heavy resource footprint (gigabytes of RAM/disk).
  * **Container:**
    - Virtualizes the operating system user space.
    - Multiple containers share the underlying **host OS kernel**.
    - Isolated using Linux kernel primitives: **Namespaces** (PID, NET, MNT, IPC, UTS, USER) and **Cgroups** (CPU, memory, disk I/O limits).
    - Lightweight, boots in milliseconds, minimal overhead.

---

### Q2: Explain the underlying Linux kernel technologies that make containers possible.
* **Answer:**
  1. **Namespaces:** Provides process isolation:
     - `PID`: Process IDs (PID 1 inside container vs host PID).
     - `NET`: Network interfaces, IP routing, port bindings.
     - `MNT`: Mount points and filesystem views.
     - `IPC`: Inter-Process Communication and shared memory.
     - `UTS`: Hostnames and domain names.
     - `USER`: User and group ID mappings.
  2. **Control Groups (cgroups):** Enforces resource metering and limits (e.g., restricting a container to 512MB RAM and 1 CPU core).
  3. **Union File System (UnionFS / OverlayFS):** Enables layered, copy-on-write (CoW) filesystems.
  4. **chroot / pivot_root:** Changes the apparent root directory for the running process.

---

### Q3: Explain the Docker Engine architecture (Client, Daemon, containerd, runc).
* **Answer:**
  * **Docker CLI (`docker`):** The command-line client communicating with the daemon via REST API / Unix socket (`/var/run/docker.sock`).
  * **Docker Daemon (`dockerd`):** High-level daemon managing images, networks, volumes, and API requests.
  * **containerd:** An OCI-compliant core container runtime that manages complete container lifecycles (pulling images, execution supervision).
  * **runc:** The low-level OCI reference runtime directly interfacing with Linux kernel namespaces and cgroups to spawn the actual container process.

---

## 2. Dockerfiles & Image Optimization

### Q4: What are Multi-Stage Builds in Docker, and why are they important?
* **Answer:**
  * **Multi-stage builds** use multiple `FROM` instructions in a single `Dockerfile`.
  * **Purpose:** Separate the build-time environment (compilers, SDKs, build tools like Maven, Go, npm) from the final runtime image.
  * **Benefits:**
    - Dramatically smaller final image size (e.g., Go app reduced from 1GB builder to 25MB scratch/alpine container).
    - Enhanced security by eliminating compilers, shell binaries, and build dependencies from production runtime.
* **Example:**
  ```dockerfile
  # Stage 1: Build stage
  FROM golang:1.22-alpine AS builder
  WORKDIR /app
  COPY go.mod go.sum ./
  RUN go mod download
  COPY . .
  RUN CGO_ENABLED=0 GOOS=linux go build -o server .

  # Stage 2: Minimal runtime
  FROM alpine:3.19
  RUN adduser -D -u 10001 appuser
  WORKDIR /app
  COPY --from=builder /app/server .
  USER appuser
  EXPOSE 8080
  ENTRYPOINT ["./server"]
  ```

---

### Q5: What is the difference between `CMD` and `ENTRYPOINT` in a Dockerfile?
* **Answer:**
  * `ENTRYPOINT`: Defines the fixed executable command that will always run when the container starts.
  * `CMD`: Defines the default arguments passed to the `ENTRYPOINT` (or the default command if `ENTRYPOINT` is omitted).
  * **Overriding behavior:**
    - Arguments passed to `docker run <image> arg1 arg2` will append/override `CMD`, but will *not* override `ENTRYPOINT` (unless explicitly using `--entrypoint`).
  * **Best Practice:** Use `ENTRYPOINT` for the binary and `CMD` for default operational parameters:
    ```dockerfile
    ENTRYPOINT ["nginx"]
    CMD ["-g", "daemon off;"]
    ```

---

### Q6: What is the difference between `COPY` and `ADD`?
* **Answer:**
  * `COPY`: Copies files/directories from the local build context into the container filesystem. Straightforward and transparent.
  * `ADD`: Has additional capabilities:
    - Automatically unpacks/extracts compressed tar archives (`.tar.gz`).
    - Can download files from remote URLs.
  * **Best Practice:** Always prefer `COPY` unless you explicitly require automatic tar extraction.

---

### Q7: How do you optimize Docker build cache and speed up CI builds?
* **Answer:**
  1. **Order Dockerfile instructions from least frequently changed to most frequently changed:**
     - Copy dependency definitions first (`package.json`, `go.mod`, `requirements.txt`).
     - Run dependency download (`npm install`, `pip install`).
     - Copy the remaining source code last.
  2. **Combine `RUN` commands:** Use `RUN apt-get update && apt-get install -y package && rm -rf /var/lib/apt/lists/*` to minimize intermediate image layers and remove caches in the same layer.
  3. **Use `.dockerignore`:** Exclude local files (`.git`, `node_modules`, `.env`, temporary build logs) from the build context.
  4. **Use minimal base images:** Prefer Alpine, Debian Slim, or Google Distroless base images.

---

## 3. Storage, Networking & Security

### Q8: Explain Docker Storage: Volumes vs. Bind Mounts vs. tmpfs.
* **Answer:**
  * **Named Volumes (`docker volume create`):** Managed completely by Docker in host storage (`/var/lib/docker/volumes/`). Best for persistent database storage and data sharing across containers.
  * **Bind Mounts (`-v /host/path:/container/path`):** Mounts an arbitrary file or directory from the host filesystem into the container. Dependent on host directory structure; ideal for local development hot-reloading.
  * **tmpfs Mounts:** Stored only in host memory (RAM). Never written to disk; ideal for sensitive in-memory keys or high-throughput temporary data.

---

### Q9: Explain Docker Container Network Drivers (Bridge, Host, None, Overlay).
* **Answer:**
  * **`bridge` (Default):** Creates a private internal virtual bridge network (`docker0`). Containers obtain private IPs and communicate; external traffic requires port forwarding (`-p 8080:80`).
  * **`host`:** Removes network isolation between the container and Docker host. The container shares the host's network stack directly (no port mapping needed; higher performance).
  * **`none`:** Disables all networking for the container (isolated loopback only).
  * **`overlay`:** Enables multi-host container networking across different Docker daemons (used in Docker Swarm and Kubernetes overlay networks).

---

### Q10: How do you secure Docker containers in production?
* **Answer:**
  1. **Never run containers as `root`:** Add a non-root user (`USER nonroot`).
  2. **Scan images for CVE vulnerabilities:** Integrate Trivy, Grype, or Snyk into the CI pipeline.
  3. **Make filesystem read-only:** Run with `--read-only` where possible.
  4. **Drop unnecessary Linux capabilities:** `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`.
  5. **Set resource limits:** Always restrict memory and CPU (`--memory="512m" --cpus="1.0"`) to prevent Denial of Service on the host.
  6. **Do not expose Docker Unix Socket:** Never mount `/var/run/docker.sock` inside untrusted containers.

---

## 4. Troubleshooting & Command Cheat Sheet

### Q11: A container starts and immediately exits. How do you troubleshoot it?
* **Answer:**
  1. Check container exit status: `docker ps -a` (Check `Exit Code`).
     - Exit 0: Command completed normally (no long-running foreground daemon).
     - Exit 1 / General error: Application crash/unhandled exception.
     - Exit 137: Killed by `SIGKILL` or kernel **OOMKilled** (Out of Memory).
     - Exit 139: Segmentation fault.
  2. Check logs: `docker logs <container-id>` or `docker logs --tail 100 -f <container-id>`.
  3. Inspect container metadata: `docker inspect <container-id>`.
  4. Run container interactively with an override entrypoint to inspect filesystem:
     ```bash
     docker run --rm -it --entrypoint /bin/sh <image-name>
     ```