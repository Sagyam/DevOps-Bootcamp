# Docker — Hands-On Lessons

Work through these in order. Each file is standalone: read it, copy the commands, run them, and clean up at the end before moving on. Every example is meant to run as-is on a machine with Docker installed.

Check your setup before you start:

```bash
docker version
docker run --rm hello-world
```

If both print output without errors, you are ready.

## Order

1. `01-docker-commands.md` — Everyday commands: search, pull, run, expose, start/stop, remove
2. `02-dockerfile-basics.md` — Build your first image from a Dockerfile
3. `03-dockerfile-instructions.md` — What each Dockerfile instruction does
4. `04-dockerfile-best-practices.md` — Small, fast, and secure images
5. `05-container-networking.md` — How containers find and talk to each other
6. `06-volumes-and-storage.md` — Keep data alive after a container is gone
7. `07-docker-hub-registry.md` — Push and pull images on Docker Hub
8. `08-custom-registry-harbor.md` — Run your own registry and scan images
9. `09-docker-compose.md` — Define and run multi-container apps
10. `10-cicd-pipeline.md` — Build and push images automatically with CI/CD
11. `11-docker-swarm.md` — Run containers across multiple machines

## A note on cleanup

Containers and images pile up fast. When a lesson tells you to clean up, do it. If things get messy, this removes stopped containers, unused networks, and dangling images:

```bash
docker system prune
```
