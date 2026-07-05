# 03 — Dockerfile Instructions

Each instruction does one job. Here is what each one means, with a small snippet you can drop into a Dockerfile.

## FROM — the base image

Every Dockerfile starts here. It sets the starting point you build on top of.

```dockerfile
FROM python:3.12-slim
```

## WORKDIR — set the working directory

Sets the directory that later `COPY`, `RUN`, and `CMD` instructions run inside. It is created if it doesn't exist.

```dockerfile
WORKDIR /app
```

## COPY — copy files in

Copies files from your build folder into the image.

```dockerfile
COPY requirements.txt .
COPY . .
```

## ADD — copy, plus extras

Like `COPY`, but can also unpack a local tar file or fetch a URL. Prefer `COPY` unless you need those extras.

```dockerfile
ADD project.tar.gz /app/
```

## RUN — run a command at build time

Executes during the build and bakes the result into a layer. Use it to install packages.

```dockerfile
RUN pip install --no-cache-dir -r requirements.txt
```

## ENV — set environment variables

Available during build and inside the running container.

```dockerfile
ENV APP_PORT=5000
```

## ARG — build-time variable

Only exists during the build, not in the final running container.

```dockerfile
ARG VERSION=1.0
RUN echo "Building version $VERSION"
```

Pass a value at build time:

```bash
docker build --build-arg VERSION=2.0 -t myapp .
```

## EXPOSE — document the port

Declares which port the app listens on. It is documentation — you still publish with `-p` at run time.

```dockerfile
EXPOSE 5000
```

## VOLUME — mark a data directory

Marks a path whose data should live outside the container's writable layer.

```dockerfile
VOLUME /data
```

## USER — drop root

Switch to a non-root user for everything after this line.

```dockerfile
RUN useradd --create-home appuser
USER appuser
```

## LABEL — add metadata

```dockerfile
LABEL maintainer="you@example.com"
```

## HEALTHCHECK — tell Docker how to test the app

Docker runs this command periodically and marks the container healthy or unhealthy.

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:5000/ || exit 1
```

## CMD vs ENTRYPOINT

Both define what runs when the container starts. The difference is how they combine with arguments.

**CMD** sets a default command that is easy to override:

```dockerfile
CMD ["python", "app.py"]
```

```bash
# Runs python app.py
docker run myapp
# Overrides it entirely — runs "bash" instead
docker run myapp bash
```

**ENTRYPOINT** sets a fixed command; anything you pass at run time becomes its arguments:

```dockerfile
ENTRYPOINT ["python", "app.py"]
```

```bash
# Runs: python app.py --debug
docker run myapp --debug
```

A common pattern combines them — `ENTRYPOINT` is the program, `CMD` is the default argument:

```dockerfile
ENTRYPOINT ["python", "app.py"]
CMD ["--port=5000"]
```

## Shell form vs exec form

You will see two syntaxes:

```dockerfile
CMD python app.py            # shell form — runs inside /bin/sh -c
CMD ["python", "app.py"]     # exec form — runs directly
```

Prefer the exec form (the JSON array). It passes signals like `Ctrl+C` and `docker stop` straight to your app, so it shuts down cleanly.
