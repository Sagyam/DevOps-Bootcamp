# 02 — Building an Image from a Dockerfile

You have been running images other people built. Now you build your own. A **Dockerfile** is a recipe: Docker reads it top to bottom and produces an image.

## Set up the project

Create a folder and three files:

```bash
mkdir flask-hello && cd flask-hello
```

`app.py`:

```python
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello from Docker!\n"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

`requirements.txt`:

```text
flask==3.0.3
```

`Dockerfile`:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
```

## Build the image

The `-t` flag names (tags) the image. The `.` tells Docker to build using the current folder:

```bash
docker build -t flask-hello .
```

Confirm it exists:

```bash
docker images | grep flask-hello
```

## Run it

```bash
docker run -d -p 5000:5000 --name hello flask-hello
curl http://localhost:5000
```

You should see `Hello from Docker!`.

## Why the file is ordered this way

Docker caches each instruction as a layer. `requirements.txt` is copied and installed **before** the rest of your code, so editing `app.py` later doesn't force a reinstall of dependencies. Rebuild after a code change to see the cache in action:

```bash
docker build -t flask-hello .
```

The dependency layers say `CACHED` and the build finishes in seconds.

## Clean up

```bash
docker rm -f hello
docker rmi flask-hello
cd ..
```
