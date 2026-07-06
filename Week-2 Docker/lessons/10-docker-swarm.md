# 11 — Docker Swarm & Orchestration

Compose runs many containers on **one** machine. When you need to run across **several** machines — for capacity and so one dead server doesn't take the app down — you need an **orchestrator**. Docker's built-in one is **Swarm**. (Kubernetes is the industry standard for large systems; Swarm is the gentlest way to learn the ideas.)

## What an orchestrator does for you

- Spreads containers ("tasks") across multiple machines ("nodes")
- Restarts a container automatically if it crashes
- Scales a service up or down on command
- Load-balances traffic across all replicas
- Rolls out new versions with zero downtime

## Start a swarm

You can do the whole lesson on a single machine. Turn the current host into a swarm manager:

```bash
docker swarm init
```

The output prints a `docker swarm join` command with a token — that is what you would run on other machines to add them as workers. Check your nodes:

```bash
docker node ls
```

## Run a service

A **service** is the swarm equivalent of a container, but managed. Create one with 3 replicas:

```bash
docker service create --name web --replicas 3 -p 8080:80 nginx
```

See it and its tasks:

```bash
docker service ls
docker service ps web
```

Three copies of nginx are now running, all reachable on port 8080 — swarm load-balances across them automatically.

```bash
curl http://localhost:8080
```

## Self-healing

Kill one of the replica containers directly:

```bash
docker ps --filter name=web -q | head -n1 | xargs docker rm -f
```

Check the tasks again after a moment:

```bash
docker service ps web
```

Swarm noticed the missing replica and started a new one to get back to 3. You never told it to — that is the orchestrator's job.

## Scale up and down

```bash
docker service scale web=5
docker service ps web
docker service scale web=2
```

## Rolling updates

Update the image with no downtime — swarm replaces replicas a few at a time:

```bash
docker service update --image nginx:1.27 web
```

## Deploy a whole stack

Instead of one service at a time, deploy a multi-service app from a Compose file. Swarm calls this a **stack**. Create `stack.yaml`:

```yaml
services:
  web:
    image: nginx
    ports:
      - "8080:80"
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
```

Deploy it:

```bash
docker stack deploy -c stack.yaml mysite
docker stack services mysite
```

The `deploy:` section (replicas, restart policy, update strategy) is the swarm-specific part — plain Compose ignores it, but `docker stack deploy` uses it.

## Clean up

```bash
docker stack rm mysite
docker service rm web 2>/dev/null
docker swarm leave --force
```

## Where this leads

Swarm teaches the vocabulary — nodes, services, replicas, rolling updates, self-healing — that carries directly into **Kubernetes**, which is where most production orchestration happens today. Learn the concepts here; apply them there next.
