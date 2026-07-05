# 01 — Everyday Docker Commands

These are the commands you will use every day. Run them top to bottom.

## Search for an image

Find images on Docker Hub from the terminal:

```bash
docker search nginx
```

## Download (pull) an image

Pull the default `latest` tag, or pin a version:

```bash
docker pull nginx
docker pull nginx:1.27
```

Pinning a version (`nginx:1.27`) is the habit to build — `latest` changes under you.

## List images

See what you have downloaded:

```bash
docker images
```

## Create a container (without starting it)

`create` prepares a container but leaves it stopped:

```bash
docker create --name web nginx
```

## Run a container

`run` = create + start in one step. Run in the background with `-d`:

```bash
docker run -d --name web2 nginx
```

## Expose an application on a port

Map a port on your machine to a port inside the container using `-p HOST:CONTAINER`. Here your machine's `8080` forwards to nginx's `80`:

```bash
docker run -d -p 8080:80 --name site nginx
```

Now open it:

```bash
curl http://localhost:8080
```

You should see the nginx welcome HTML.

## List running containers

```bash
docker ps
```

Add `-a` to include stopped ones:

```bash
docker ps -a
```

## See logs

```bash
docker logs site
```

## Get a shell inside a running container

```bash
docker exec -it site bash
```

Type `exit` to leave.

## Stop and start

```bash
docker stop site
docker start site
```

## Remove a container

Stop it first, then remove — or force-remove a running one with `-f`:

```bash
docker stop site
docker rm site
docker rm -f web2
```

## Remove an image

```bash
docker rmi nginx:1.27
```

## Clean up this lesson

```bash
docker rm -f web web2 site 2>/dev/null
docker rmi nginx nginx:1.27 2>/dev/null
```

## Quick reference

| Task | Command |
|------|---------|
| Search | `docker search <image>` |
| Pull | `docker pull <image>:<tag>` |
| List images | `docker images` |
| Run in background | `docker run -d --name <name> <image>` |
| Publish a port | `docker run -d -p <host>:<container> <image>` |
| List running | `docker ps` |
| List all | `docker ps -a` |
| Logs | `docker logs <name>` |
| Shell in | `docker exec -it <name> bash` |
| Stop / start | `docker stop <name>` / `docker start <name>` |
| Remove container | `docker rm <name>` (`-f` to force) |
| Remove image | `docker rmi <image>` |
