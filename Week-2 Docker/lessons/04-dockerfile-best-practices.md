# 04 — Best Practices & Security

A working image is not enough — it should be small, build fast, and be safe to ship. Here are the practices that matter, each with something you can run.

## 1. Use a `.dockerignore`

Stop Docker from copying junk (git history, local venvs, secrets) into the build. Create `.dockerignore` next to your Dockerfile:

```text
.git
__pycache__
*.pyc
.env
node_modules
```

## 2. Pin your versions

Vague tags drift over time and break reproducibility.

```dockerfile
# Avoid
FROM python:latest

# Prefer
FROM python:3.12-slim
```

## 3. Order instructions for the cache

Put things that rarely change (dependencies) above things that change often (your code). This was covered in lesson 02 — copy and install dependencies first, then copy the rest.

## 4. Choose small base images

`slim` and `alpine` variants are a fraction of the full image size. Compare:

```bash
docker pull python:3.12
docker pull python:3.12-slim
docker images | grep python
```

The `slim` image is much smaller, which means faster pulls and a smaller attack surface.

## 5. Use multi-stage builds

Build with a heavy toolchain, then ship only the final artifact in a tiny image. This Go example produces a final image of only a few MB.

`main.go`:

```go
package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello from a tiny image!")
	})
	http.ListenAndServe(":8080", nil)
}
```

`go.mod`:

```text
module hello

go 1.23
```

`Dockerfile`:

```dockerfile
# Stage 1: build the binary
FROM golang:1.23 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app .

# Stage 2: ship only the binary
FROM gcr.io/distroless/static-debian12
COPY --from=build /app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

Build and run:

```bash
docker build -t tiny-go .
docker run -d -p 8080:8080 --name tiny tiny-go
curl http://localhost:8080
docker images | grep tiny-go
```

The final image carries no compiler, no shell, no package manager — just your program.

## 6. Run as a non-root user

By default containers run as root. If someone breaks out of your app, they are root. Add a user and switch to it:

```dockerfile
FROM python:3.12-slim
RUN useradd --create-home appuser
WORKDIR /home/appuser
USER appuser
```

## 7. Never bake secrets into an image

Anything you `COPY` or `ENV` into an image can be read by anyone who pulls it. Pass secrets at run time instead:

```bash
docker run -e API_KEY=xxxx myapp
```

## 8. Scan images for vulnerabilities

Docker ships with **Scout**. Point it at an image to list known CVEs:

```bash
docker scout cves tiny-go
```

**Trivy** is a popular standalone scanner you can also run in a container:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image nginx:1.27
```

Make scanning part of your build pipeline (see lesson 10), not a one-off.

## Clean up

```bash
docker rm -f tiny
docker rmi tiny-go
```

## Checklist

- [ ] `.dockerignore` present
- [ ] Base image pinned to a specific version
- [ ] Dependencies installed before app code (cache-friendly)
- [ ] Slim / distroless base
- [ ] Multi-stage build where a toolchain is involved
- [ ] Runs as a non-root user
- [ ] No secrets in the image
- [ ] Image scanned before it ships
