# CI and CD 

## 1. Core CI/CD Concepts & Deployment Strategies

### Q1: What is the difference between Continuous Integration, Continuous Delivery, and Continuous Deployment?
* **Answer:**
  * **Continuous Integration (CI):** Developers frequently merge code into a shared repository. Every push triggers automated builds, linters, unit tests, and security scans to detect bugs early.
  * **Continuous Delivery (CD):** Extends CI by automatically packaging and deploying validated code to staging/pre-production environments. Deployments to production require a **manual approval gate**.
  * **Continuous Deployment (CD):** Fully automated end-to-end pipeline where every change that passes all automated tests and quality gates is automatically deployed straight to **production with zero human intervention**.

---

### Q2: Explain Blue/Green, Canary, and Rolling Deployment strategies.
* **Answer:**
  * **Rolling Deployment:**
    - Gradually replaces old instances of the application with new versions one by one (or batch by batch) behind a load balancer until all instances run the new version.
    - *Pros:* Zero downtime, no extra duplicate hardware required.
    - *Cons:* During rollout, both versions run concurrently (requires backward-compatible APIs and databases).
  * **Blue/Green Deployment:**
    - Maintains two identical production environments: Blue (current active version) and Green (new version idle).
    - Deploy and test the new release fully on Green. Once verified, switch the router/load balancer traffic from Blue to Green instantly.
    - *Pros:* Instant cutover, instantaneous rollback (switch traffic back to Blue).
    - *Cons:* High infrastructure cost (requires 2x resource capacity).
  * **Canary Deployment:**
    - Routes a small percentage of real production traffic (e.g., 5%) to the new release while 95% remains on the stable version.
    - Metrics (error rates, latency) are monitored. If healthy, traffic is incrementally increased (25% -> 50% -> 100%).
    - *Pros:* Limits blast radius of bugs on real users.

---

## 2. GitHub Actions Deep Dive

### Q3: Explain the core components of a GitHub Actions workflow.
* **Answer:**
  * **Workflows:** Automated YAML configuration files stored in `.github/workflows/`.
  * **Events / Triggers (`on:`):** Specific activities that trigger a workflow (e.g., `push`, `pull_request`, `schedule` (cron), `workflow_dispatch` (manual trigger)).
  * **Jobs:** A set of steps executed on the same runner. Jobs run in **parallel** by default, or sequentially using `needs: [job_name]`.
  * **Steps:** Individual tasks within a job that run commands (`run:`) or execute reusable actions (`uses:`).
  * **Runners:** Virtual machines or containers executing the jobs (GitHub-hosted runners or Self-hosted runners).

---

### Q4: How do you securely manage sensitive credentials (secrets) in GitHub Actions?
* **Answer:**
  1. Store secrets in **GitHub Secrets** (Repository, Environment, or Organization level).
  2. Reference secrets securely in workflow YAML:
     ```yaml
     env:
       DATABASE_PASSWORD: ${{ secrets.DB_PASSWORD }}
     ```
  3. GitHub Actions automatically masks registered secrets in console logs (`***`).
  4. For cloud provider authentication (e.g., AWS), prefer **OIDC (OpenID Connect)** over long-lived hardcoded IAM credentials (`aws-actions/configure-aws-credentials` with IAM Roles).
  5. Never print secrets to stdout or bypass masking.

---

### Q5: Write a simple GitHub Actions workflow to build, test, and package a Node.js application.
* **Answer:**
  ```yaml
  name: Node.js CI Pipeline

  on:
    push:
      branches: [ main ]
    pull_request:
      branches: [ main ]

  jobs:
    build-and-test:
      runs-on: ubuntu-latest
      strategy:
        matrix:
          node-version: [ 18.x, 20.x ]

      steps:
        - name: Checkout Source Code
          uses: actions/checkout@v4

        - name: Setup Node.js ${{ matrix.node-version }}
          uses: actions/setup-node@v4
          with:
            node-version: ${{ matrix.node-version }}
            cache: 'npm'

        - name: Install Dependencies
          run: npm ci

        - name: Run Linters & Tests
          run: |
            npm run lint
            npm test -- --coverage

        - name: Build Docker Image
          if: github.ref == 'refs/heads/main' && matrix.node-version == '20.x'
          run: |
            docker build -t myapp:${{ github.sha }} .
  ```

---

## 3. Jenkins Deep Dive

### Q6: Explain Jenkins Architecture (Controller/Master and Agent/Node).
* **Answer:**
  * **Jenkins Controller (formerly Master):**
    - Serves the web UI and REST API.
    - Stores pipeline configurations, build logs, plugin management, and credentials.
    - Schedules build jobs and dispatches them to worker agents.
    - **Best Practice:** Do not execute build jobs directly on the Controller to avoid resource exhaustion and security vulnerabilities.
  * **Jenkins Agent (Node / Worker):**
    - Lightweight process running on separate VMs, bare-metal, or ephemeral Kubernetes Pods.
    - Executes the actual build steps dispatched by the Controller and reports back results.

---

### Q7: What is the difference between Declarative and Scripted Pipelines in Jenkins?
* **Answer:**
  * **Declarative Pipeline (Recommended):**
    - Uses a structured, opinionated syntax enclosed in a `pipeline { ... }` block.
    - Easier to read, write, and validate with built-in linting.
    - Enforces standard sections (`agent`, `stages`, `stage`, `steps`, `post`).
  * **Scripted Pipeline:**
    - Uses Groovy code directly within a `node { ... }` block.
    - Maximum flexibility and imperative programming logic (loops, dynamic conditions).
    - Harder to maintain and troubleshoot.

---

### Q8: Write a sample Declarative `Jenkinsfile` with build, test, and post-actions.
* **Answer:**
  ```groovy
  pipeline {
      agent any

      environment {
          APP_NAME = 'billing-service'
          DOCKER_CRED_ID = 'dockerhub-credentials'
      }

      stages {
          stage('Checkout') {
              steps {
                  checkout scm
              }
          }

          stage('Build') {
              steps {
                  sh 'echo "Compiling application..."'
                  sh './mvnw clean compile'
              }
          }

          stage('Unit & Integration Test') {
              steps {
                  sh './mvnw test'
              }
          }

          stage('Docker Build & Push') {
              when {
                  branch 'main'
              }
              steps {
                  withCredentials([usernamePassword(credentialsId: "${DOCKER_CRED_ID}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                      sh '''
                          docker build -t $DOCKER_USER/$APP_NAME:${BUILD_NUMBER} .
                          echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                          docker push $DOCKER_USER/$APP_NAME:${BUILD_NUMBER}
                      '''
                  }
              }
          }
      }

      post {
          always {
              cleanWs() // Clean workspace after build
          }
          success {
              echo "Pipeline executed successfully!"
          }
          failure {
              echo "Pipeline failed! Sending Slack alert notification..."
          }
      }
  }
  ```

---

## 4. Pipeline Optimization & Troubleshooting

### Q9: How do you optimize slow CI/CD pipelines?
* **Answer:**
  1. **Dependency Caching:** Cache package manager directories (`~/.npm`, `~/.m2`, `~/.cache/pip`, Go module cache) so dependencies aren't re-downloaded every run.
  2. **Parallelization:** Run independent jobs concurrently (e.g., unit tests, frontend linting, security scans in parallel).
  3. **Docker Layer Caching:** Leverage remote image cache or Buildx caching (`cache-from`, `cache-to`).
  4. **Ephemeral Runners:** Use autoscaling, ephemeral Kubernetes pod agents that spin up on-demand and destroy immediately.
  5. **Selective Testing:** Run only tests related to modified packages in monorepos.