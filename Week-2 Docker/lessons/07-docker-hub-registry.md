# 07 — Docker Hub & Registries

A **registry** is where images live. When you `docker pull nginx`, you are pulling from **Docker Hub**, the default public registry. This lesson is about pushing your own images there.

## Anatomy of an image name

```
docker.io / library / nginx : 1.27
└registry┘  └ user ┘  └repo┘  └tag┘
```

- Official images (like `nginx`, `redis`, `postgres`) live under the hidden `library` namespace, so you just write `nginx`.
- Your own images live under your username: `yourname/myapp`.

## Types of images on Docker Hub

- **Official images** — maintained by Docker, curated, well documented. Prefer these as base images.
- **Verified Publisher** — from trusted vendors (e.g. `bitnami`).
- **Community images** — anyone can publish. Check the source and download count before trusting one.

## Log in

Create a free account at hub.docker.com, then:

```bash
docker login
```

Enter your username and an **access token** (create one under Account Settings → Security). Use a token, not your password.

## Build and tag an image for your account

Reuse the app from lesson 02, or any image. Tag it with `yourname/repo:tag`:

```bash
docker build -t yourname/flask-hello:1.0 .
```

Already built it under a different name? Re-tag instead of rebuilding:

```bash
docker tag flask-hello yourname/flask-hello:1.0
```

Replace `yourname` with your real Docker Hub username everywhere below.

## Push it

```bash
docker push yourname/flask-hello:1.0
```

It now appears in your Docker Hub repositories, and anyone can pull it:

```bash
docker pull yourname/flask-hello:1.0
```

## Tag the same image as `latest`

You can attach multiple tags to one image:

```bash
docker tag yourname/flask-hello:1.0 yourname/flask-hello:latest
docker push yourname/flask-hello:latest
```

## Public vs private repositories

New repos default to public. In the repository settings on Docker Hub you can switch it to **private** so only accounts you grant access can pull it.


