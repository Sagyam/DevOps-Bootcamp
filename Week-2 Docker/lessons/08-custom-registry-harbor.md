# 08 — Your Own Registry & Harbor

Not everything belongs on public Docker Hub. Companies run their own registries for private images, speed, and control. You will start with the simple built-in registry, then meet Harbor, a full-featured one.

## Part 1: A local registry in one command

Docker publishes an official `registry` image. Run it:

```bash
docker run -d -p 5000:5000 --name registry registry:2
```

You now have a registry at `localhost:5000`.

### Push an image to it

Tag any image with the registry's address as a prefix, then push:

```bash
docker pull alpine:3.20
docker tag alpine:3.20 localhost:5000/alpine:3.20
docker push localhost:5000/alpine:3.20
```

### Pull it back

Prove it works by deleting the local copy and pulling from your registry:

```bash
docker rmi localhost:5000/alpine:3.20
docker pull localhost:5000/alpine:3.20
```

### Browse the registry's contents

The registry has a simple HTTP API:

```bash
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/alpine/tags/list
```

### Clean up part 1

```bash
docker rm -f registry
docker rmi localhost:5000/alpine:3.20 alpine:3.20 2>/dev/null
```

The plain `registry` is minimal: no web UI, no user accounts, no scanning. For real use, you want Harbor.

## Part 2: Harbor — a production-grade registry

**Harbor** is an open-source registry from the CNCF. On top of storing images it adds a web UI, user and project permissions, image signing, replication between registries, and a built-in **vulnerability scanner** (Trivy).

### Install Harbor

Harbor ships as a set of containers orchestrated by Docker Compose. On a Linux host:

```bash
# Download the offline installer (check github.com/goharbor/harbor/releases for the latest version)
wget https://github.com/goharbor/harbor/releases/download/v2.11.1/harbor-offline-installer-v2.11.1.tgz
tar xzvf harbor-offline-installer-v2.11.1.tgz
cd harbor
```

Copy the template config and edit it:

```bash
cp harbor.yml.tmpl harbor.yml
```

In `harbor.yml`, set at least these:

```yaml
hostname: registry.example.local     # your host's IP or DNS name
harbor_admin_password: ChangeMe123
```

Then run the installer with the scanner enabled:

```bash
sudo ./install.sh --with-trivy
```

When it finishes, open `http://registry.example.local` in a browser and log in as `admin` with the password you set.

### Use Harbor

In the UI, create a **Project** (e.g. `bootcamp`), then from the terminal:

```bash
docker login registry.example.local
docker tag flask-hello registry.example.local/bootcamp/flask-hello:1.0
docker push registry.example.local/bootcamp/flask-hello:1.0
```

### The security scanner

Because you installed `--with-trivy`, Harbor can scan every image. In the UI, open your image and click **Scan** — Harbor lists vulnerabilities by severity. You can go further and set a project policy to **block pulls** of images above a chosen severity, so a vulnerable image can never be deployed.

This is the real payoff of a custom registry over Docker Hub: you control who can push and pull, and you can enforce that only scanned, clean images move forward.
