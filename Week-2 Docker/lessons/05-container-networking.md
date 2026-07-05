# 05 — Container Networking

Containers are isolated by default. Networking is how they reach the outside world and each other.

## List networks

Docker creates a few networks for you:

```bash
docker network ls
```

You will see `bridge`, `host`, and `none` — the three built-in driver types.

## The network types

- **bridge** (default) — a private internal network on your host. Containers get their own IPs and can talk to each other; the outside world reaches them only through published ports (`-p`).
- **host** — the container shares your host's network directly. No isolation, no port mapping needed. Linux only.
- **none** — no networking at all. Fully isolated.
- **overlay** — spans multiple hosts. Used by Swarm (lesson 11).
- **macvlan** — gives a container its own MAC/IP as if it were a physical device on your LAN. For special cases.

## The key idea: name-based discovery

On the **default** bridge network, containers can only reach each other by IP. But on a **user-defined** bridge network, Docker gives you built-in DNS — containers reach each other by name. This is the pattern you will use constantly.

## Hands-on: two containers talking

Create a network:

```bash
docker network create appnet
```

Start Redis on it:

```bash
docker run -d --name redis --network appnet redis:7
```

Now start a temporary Redis client on the same network and reach the server **by name** (`redis`), not by IP:

```bash
docker run -it --rm --network appnet redis:7 redis-cli -h redis ping
```

You should see `PONG`. The name `redis` resolved automatically because both containers share `appnet`.

## Inspect a network

See which containers are attached and their IPs:

```bash
docker network inspect appnet
```

## Connect an existing container to a network

```bash
docker run -d --name web nginx
docker network connect appnet web
```

Now `web` is on both its default network and `appnet`.

## host and none

Run on the host's network directly (Linux):

```bash
docker run -d --name hostnginx --network host nginx
```

Run with no network:

```bash
docker run -it --rm --network none alpine ip addr
```

You will see only the loopback interface — no way in or out.

## Publishing ports (recap)

`bridge` containers are reached from outside via `-p HOST:CONTAINER`:

```bash
docker run -d -p 8080:80 --name site nginx
curl http://localhost:8080
```

## Clean up

```bash
docker rm -f redis web hostnginx site 2>/dev/null
docker network rm appnet
```
