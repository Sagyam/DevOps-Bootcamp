# 06 — Volumes & Persistent Storage

When a container is removed, everything written inside it is gone. To keep data — a database, uploaded files, logs — you store it **outside** the container. There are three ways.

## 1. Named volumes (the default choice)

Docker manages the storage for you. Best for databases and app data.

Create one and list it:

```bash
docker volume create pgdata
docker volume ls
```

Mount it into a container with `-v VOLUME:PATH`:

```bash
docker run -d --name db \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

### Prove that data survives

Write some data:

```bash
docker exec -it db psql -U postgres -c "CREATE TABLE students (name TEXT);"
docker exec -it db psql -U postgres -c "INSERT INTO students VALUES ('Ada');"
```

Destroy the container completely:

```bash
docker rm -f db
```

Start a brand-new container on the **same volume** and read the data back:

```bash
docker run -d --name db2 \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

sleep 5
docker exec -it db2 psql -U postgres -c "SELECT * FROM students;"
```

`Ada` is still there. The container was disposable; the data was not.

## 2. Bind mounts (for local development)

Mount a folder from your machine straight into the container. Edit files on your host and the container sees them instantly. Great for development.

```bash
mkdir site && echo "<h1>Live edit</h1>" > site/index.html

docker run -d --name web \
  -p 8080:80 \
  -v "$(pwd)/site":/usr/share/nginx/html \
  nginx

curl http://localhost:8080
```

Now edit the file on your host and refresh — no rebuild needed:

```bash
echo "<h1>Changed!</h1>" > site/index.html
curl http://localhost:8080
```

## 3. tmpfs (memory only)

Stores data in RAM. Fast, and wiped when the container stops. Use it for scratch data or secrets you never want on disk (Linux only).

```bash
docker run -it --rm --tmpfs /scratch alpine sh -c "df -h /scratch"
```

## Named volume vs bind mount — which one?

| | Named volume | Bind mount |
|---|---|---|
| Managed by | Docker | You |
| Best for | Databases, production data | Local development |
| Location | Docker's storage area | A path you choose |
| Portable across machines | Yes | No (tied to host paths) |

## Inspect and remove volumes

```bash
docker volume inspect pgdata
docker volume rm pgdata          # must not be in use
docker volume prune              # remove all unused volumes
```

## Clean up

```bash
docker rm -f db db2 web 2>/dev/null
docker volume rm pgdata 2>/dev/null
rm -rf site
```
