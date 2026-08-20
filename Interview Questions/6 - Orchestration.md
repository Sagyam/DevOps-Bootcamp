# Kubernetes

## 1. Kubernetes Architecture

### Q1: Describe the high-level architecture of Kubernetes (Control Plane vs. Worker Nodes).
* **Answer:**
  * **Control Plane Components (Master):**
    - **`kube-apiserver`:** The central REST API gateway and entry point for all administrative and internal communication. All components talk to `kube-apiserver`.
    - **`etcd`:** Highly available, distributed key-value store holding the complete cluster state and configuration.
    - **`kube-scheduler`:** Assigns newly created unscheduled Pods to suitable worker nodes based on resource requests, constraints, taints/tolerations, and affinity rules.
    - **`kube-controller-manager`:** Runs controller loops regulating cluster state (Node Controller, Deployment Controller, EndpointSlice Controller, ServiceAccount Controller).
    - **`cloud-controller-manager`:** Integrates with underlying cloud provider APIs (load balancers, storage volumes, node routing).
  * **Worker Node Components:**
    - **`kubelet`:** Node agent that registers the node, watches for Pod assignments from the API server, instructs the container runtime to start containers, and monitors Pod health.
    - **`kube-proxy`:** Network proxy managing IP routing and iptables/IPVS rules on each node to implement Kubernetes `Service` networking.
    - **Container Runtime (CRI):** Software responsible for running containers (e.g., containerd, CRI-O).

---

## 2. Core Kubernetes Primitives

### Q2: What is a Pod? Why doesn't Kubernetes run containers directly?
* **Answer:**
  * A **Pod** is the smallest deployable compute unit in Kubernetes.
  * It represents a single instance of a running process in the cluster.
  * A Pod encapsulates one or more containers that:
    - Share the same Network namespace (same IP address, port space, and `localhost` communication).
    - Share storage volumes mounted into the Pod.
  * *Why Pods?* Pods enable the **Sidecar Pattern** (e.g., a primary web container paired with a logging agent or service mesh proxy container like Envoy) that co-locate and share lifecycle and resources.

---

### Q3: Explain Deployments vs. StatefulSets vs. DaemonSets vs. Jobs.
* **Answer:**
  * **Deployment:** Best for **stateless** applications (web servers, APIs). Manages scaling, rolling updates, rollbacks, and self-healing via ReplicaSets. Pods are ephemeral and interchangeable.
  * **StatefulSet:** Best for **stateful** workloads (databases like PostgreSQL, Redis, Kafka). Provides:
    - Stable, persistent unique network identifiers (`pod-0`, `pod-1`).
    - Dedicated persistent storage per replica (via `volumeClaimTemplates`).
    - Ordered, sequential deployment, scaling, and termination.
  * **DaemonSet:** Ensures that **all (or selected) nodes run exactly one copy** of a Pod. Ideal for cluster logging (Fluentd/Logstash), node monitoring (Prometheus Node Exporter), and networking plugins (Calico, kube-proxy).
  * **Job / CronJob:** Runs batch tasks to completion and terminates (e.g., database migration, backups). CronJob runs Jobs on a scheduled time (cron syntax).

---

### Q4: Explain the 4 types of Kubernetes Services.
* **Answer:**
  * **`ClusterIP` (Default):** Exposes the Service on an internal cluster IP address. Reachable only within the cluster.
  * **`NodePort`:** Exposes the Service on each node's IP at a static port (default range: 30000–32767). Allows external traffic by accessing `<NodeIP>:<NodePort>`.
  * **`LoadBalancer`:** Provisions a cloud provider's external load balancer (e.g., AWS NLB/ALB) that automatically routes traffic into NodePorts / ClusterIP.
  * **`ExternalName`:** Maps the Service to an external DNS CNAME string (e.g., `my-db.external.com`) without proxying.

---

### Q5: What is an Ingress and how does it differ from a LoadBalancer Service?
* **Answer:**
  * A `LoadBalancer` service operates at Layer 4 (TCP/UDP) and provisions a separate cloud load balancer for each service (which can become expensive).
  * An **Ingress** operates at Layer 7 (HTTP/HTTPS) and acts as an intelligent router/reverse proxy:
    - Provides path-based routing (e.g., `api.example.com/orders` vs `api.example.com/users`).
    - Provides host-based routing (`app1.example.com` vs `app2.example.com`).
    - Handles SSL/TLS termination centrally with a single external IP / Load Balancer.
    - Requires an **Ingress Controller** (e.g., NGINX Ingress, Traefik, AWS ALB Controller) to satisfy the Ingress rules.

---

## 3. Pod Lifecycle, Health Probes & Resource Management

### Q6: Explain Liveness, Readiness, and Startup Probes.
* **Answer:**
  * **`livenessProbe`:** Determines if the container is still running and healthy. If the liveness probe fails, the kubelet kills the container and initiates a restart according to the `restartPolicy`.
  * **`readinessProbe`:** Determines if the container is ready to accept incoming network traffic. If it fails, Kubernetes removes the Pod's IP from the matching Service Endpoints so no traffic is routed to it (the Pod is **not** restarted).
  * **`startupProbe`:** Designed for legacy or slow-starting applications. Disables liveness and readiness checks until the startup probe succeeds, preventing premature container restarts during long initializations.

---

### Q7: What is the difference between Resource Requests and Limits? What is OOMKilled?
* **Answer:**
  * **`requests`:** The minimum guaranteed amount of CPU or Memory that Kubernetes requires to schedule the Pod on a node. The scheduler uses requests for placement decisions.
  * **`limits`:** The hard maximum ceiling of CPU or Memory a container is allowed to consume.
  * **CPU vs. Memory behavior under pressure:**
    - **CPU:** A compressible resource. If a container exceeds its CPU limit, it is **throttled**, but the process is not killed.
    - **Memory:** An incompressible resource. If a container exceeds its memory limit, the Linux kernel Out-Of-Memory killer terminates the container with exit status **`137 (OOMKilled)`**.

---

## 4. Kubernetes Troubleshooting Scenarios

### Q8: A Pod is stuck in `CrashLoopBackOff`. How do you troubleshoot and fix it?
* **Answer Steps:**
  1. Inspect the Pod status:
     ```bash
     kubectl get pods -n <namespace>
     ```
  2. Read the latest and previous logs:
     ```bash
     kubectl logs <pod-name> -n <namespace>
     kubectl logs <pod-name> --previous -n <namespace>
     ```
  3. Inspect Pod lifecycle events:
     ```bash
     kubectl describe pod <pod-name> -n <namespace>
     ```
  4. Common Causes:
     - Application crash due to missing environment variables or ConfigMap/Secret keys.
     - Database or external dependency unavailable.
     - Misconfigured `ENTRYPOINT` / `CMD`.
     - Liveness probe failing too aggressively (check initial delay).
     - Memory limit exceeded (`OOMKilled`).

---

### Q9: A Pod is stuck in `ImagePullBackOff` or `ErrImagePull`. What are the possible causes?
* **Answer:**
  1. Typo in the container image name or tag (e.g., `nginx:1.9999`).
  2. Target image does not exist in the remote registry.
  3. Private registry authentication missing (missing or incorrect `imagePullSecrets`).
  4. Node network issue or registry rate limiting (e.g., Docker Hub anonymous pull limits).

---

### Q10: A Pod is stuck in `Pending`. Why?
* **Answer:**
  1. **Insufficient cluster resources:** Nodes do not have enough free CPU or Memory requests to satisfy the Pod's requirements (`Insufficient cpu`, `Insufficient memory` in `kubectl describe pod`).
  2. **Node Selector / Affinity mismatch:** No node matches the specified labels.
  3. **Taints and Tolerations:** Nodes have taints that the Pod does not tolerate.
  4. **PVC Binding:** The Pod references a PersistentVolumeClaim that has not bound to a PersistentVolume.