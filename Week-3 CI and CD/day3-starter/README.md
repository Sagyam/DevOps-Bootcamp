# Day 3 — Docker images, built and shipped by CI

A small HTTP API with a **multi-stage** `Dockerfile`. Today CI does the building and
pushes the result to the **GitHub Container Registry (GHCR)** — no manual `docker push`.

Local sanity check:

```bash
npm test                 # node --test, zero dependencies
docker build -t day3-docker-app .
docker run --rm -p 3000:3000 day3-docker-app
curl localhost:3000/health
curl "localhost:3000/slug?text=Hello%20Docker"
```

The workflow at `../.github/workflows/day3-docker.yml` logs in to GHCR, uses Buildx with
layer caching, and tags the image by branch and commit SHA. After it runs, your image
appears under **Packages** on your repo's GitHub page.
