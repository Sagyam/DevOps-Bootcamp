# 09 — Docker Compose

Real apps have more than one container: a web app, a database, a cache. Starting each with a long `docker run` command and wiring the networks by hand gets old fast. **Compose** lets you describe the whole stack in one file and run it with one command.

## Build a two-service app

A web app that counts visits, backed by Redis. Create a folder:

```bash
mkdir compose-demo && cd compose-demo
```

`app.py`:

```python
import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis(host="redis", port=6379)

@app.route("/")
def hello():
    count = cache.incr("hits")
    return f"This page has been visited {count} times.\n"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

Notice `host="redis"` — the app reaches the database by **service name**, thanks to Compose's built-in networking.

`requirements.txt`:

```text
flask==3.0.3
redis==5.0.8
```

`Dockerfile`:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

`compose.yaml`:

```yaml
services:
  web:
    build: .
    ports:
      - "8000:5000"
    depends_on:
      - redis
  redis:
    image: redis:7
```

## Run the whole stack

```bash
docker compose up -d
```

Compose builds your `web` image, pulls `redis`, creates a shared network, and starts both. Test it:

```bash
curl http://localhost:8000
curl http://localhost:8000
```

The count goes up each time — and it is stored in Redis, a separate container.

## Everyday Compose commands

```bash
docker compose ps          # what's running
docker compose logs        # combined logs
docker compose logs -f web # follow one service
docker compose stop        # stop without deleting
docker compose start       # start again
docker compose down        # stop and remove containers + network
```

## Make Redis data persistent

Add a named volume so the count survives a full teardown. Update `compose.yaml`:

```yaml
services:
  web:
    build: .
    ports:
      - "8000:5000"
    depends_on:
      - redis
  redis:
    image: redis:7
    volumes:
      - redisdata:/data
    command: redis-server --save 60 1

volumes:
  redisdata:
```

Recreate the stack:

```bash
docker compose up -d
```

Now `docker compose down` followed by `docker compose up -d` keeps the visit count.

## Environment variables

Pass config into services instead of hardcoding it:

```yaml
services:
  web:
    build: .
    environment:
      - APP_ENV=production
    ports:
      - "8000:5000"
```

## Clean up

```bash
docker compose down -v      # -v also removes the named volume
cd ..
```
