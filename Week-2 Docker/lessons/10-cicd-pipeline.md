# 10 — Deploying with a CI/CD Pipeline

So far you have built and pushed images by hand. In real teams, a **pipeline** does it automatically: every time you push code, it builds the image, scans it, pushes it to a registry, and deploys it. This lesson uses **GitHub Actions**, but the shape is the same on GitLab CI, Jenkins, or others.

## The goal

On every push to `main`:

1. Check out the code
2. Build the Docker image
3. Scan it for vulnerabilities
4. Push it to Docker Hub

## Set up secrets

Never put credentials in your code. In your GitHub repo, go to **Settings → Secrets and variables → Actions** and add:

- `DOCKERHUB_USERNAME` — your Docker Hub username
- `DOCKERHUB_TOKEN` — a Docker Hub access token (from Account Settings → Security)

## The workflow file

Create `.github/workflows/docker.yml` in your repo:

```yaml
name: build-and-push

on:
  push:
    branches: [ "main" ]

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - name: Check out code
        uses: actions/checkout@v4

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ secrets.DOCKERHUB_USERNAME }}/myapp:latest
```

Commit and push this. Go to the **Actions** tab in GitHub to watch it run. When it finishes, your image is on Docker Hub — no manual `docker push` needed.

## Add a security scan (fail on serious issues)

Insert a Trivy scan step **before** the push so a vulnerable image never ships. Add this step above "Build and push", and build locally first so there is an image to scan:

```yaml
      - name: Build image for scanning
        uses: docker/build-push-action@v6
        with:
          context: .
          load: true
          tags: myapp:scan

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:scan
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
```

`exit-code: '1'` means the pipeline **fails** if any HIGH or CRITICAL vulnerability is found, stopping a bad image from being pushed.

## Tag images by commit, not just `latest`

`latest` tells you nothing about what is running. Tag with the Git commit SHA so every deploy is traceable:

```yaml
      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/myapp:latest
            ${{ secrets.DOCKERHUB_USERNAME }}/myapp:${{ github.sha }}
```

## The deploy step

The final stage pulls the new image on your server and restarts it. A simple version SSHes in and runs Compose:

```yaml
      - name: Deploy over SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          script: |
            cd /opt/myapp
            docker compose pull
            docker compose up -d
```

## The full picture

```
git push  →  build image  →  scan (fail if unsafe)  →  push to registry  →  deploy
```

Every code change now flows to production the same way, every time, with a security gate in the middle.
