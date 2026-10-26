# FinTech Instant Payment Gateway — Implementation

Working folder: `D:\devops_lab_practical` (Windows 11, Docker Desktop with Kubernetes, Jenkins, Terraform, Ansible in WSL).

---

## 1. Git [2 Marks]

1. Initialize the repository on `main` and make the first commit.
   ```powershell
   git init -b main
   Set-Content README.md "# FinTech Instant Payment Gateway" -Encoding ascii
   git add . ; git commit -m "Initial commit"
   ```
2. Create branch `release-v1.0` and add `gateway.conf`.
   ```powershell
   git checkout -b release-v1.0
   Set-Content gateway.conf "SETTLEMENT_CORE=ACTIVE" -Encoding ascii
   git add gateway.conf ; git commit -m "Add gateway.conf with SETTLEMENT_CORE=ACTIVE"
   ```
3. Merge into `main` and apply the annotated tag.
   ```powershell
   git checkout main
   git merge --no-ff release-v1.0 -m "Merge release-v1.0 into main"
   git tag -a v1.0.0-final -m "Release v1.0.0-final"
   git remote add origin https://github.com/HARSHHLEDWANI/Devops_lab.git
   ```
4. Verify.
   ```powershell
   git log --oneline --graph --all
   git show v1.0.0-final --stat
   git tag -n
   git remote -v
   ```
   Output: the graph shows `release-v1.0` merged into `main` (commit `91908a2`). `git show` prints `tag v1.0.0-final` with a Tagger line, which confirms the tag is annotated.

---

## 2. Jira [1 Mark]

1. Open project **PAY**, then **Board**, and drag **PAY-101** and **PAY-102** to **Done**.
2. Click **Complete sprint**, then **Complete**.
   Steps 1–2 can also run from the terminal through the Jira REST API: `.\jira\complete-sprint.ps1` (needs `JIRA_SITE`, `JIRA_EMAIL` and `JIRA_TOKEN`).
3. Open **Reports**, then **Burndown Chart**, and select the sprint.
   Output: the grey guideline falls in a straight line from the committed work to 0 at the sprint end. The red remaining-work line steps down as issues move to Done and reaches 0.

---

## 3. Jenkins [2 Marks]

1. Write the `Jenkinsfile` (declarative, `agent any`). Its stages are `Build & Unit Test`, `Docker Build` and `Cluster Deploy`, and each one runs `bat` inside `dir('D:/devops_lab_practical')`.
2. Jenkins runs as a Windows service on Java 21, which this Jenkins release requires. The service account has no kubeconfig of its own, so the pipeline sets `environment { KUBECONFIG = 'C:/Users/Harsh/.kube/config' }` to reach the `docker-desktop` cluster.
3. Create the job: New Item → `fintech-gateway-pipeline` → Pipeline → Definition "Pipeline script" → paste the `Jenkinsfile` → Save → Build Now.
   Output: Stage View shows 3 green stages. The console prints `SETTLEMENT_CORE=ACTIVE`, the image build and the `kubectl get all -l tier=payment` listing.

---

## 4. Docker [2 Marks]

1. Write the `Dockerfile`:
   ```dockerfile
   FROM alpine
   RUN apk add --no-cache busybox-extras && mkdir -p /www && \
       echo "Payment Settlement Active" > /www/index.html
   EXPOSE 80
   CMD echo "Payment Settlement Active" && httpd -f -p 80 -h /www
   ```
2. Build the image and run the container.
   ```powershell
   docker build -t fintech-gateway:v1.0 .
   docker run -d --name fintech-gateway -p 8081:80 fintech-gateway:v1.0
   ```
3. Verify.
   ```powershell
   docker ps
   docker logs fintech-gateway
   curl.exe http://localhost:8081
   ```
   Output: `docker ps` shows `fintech-gateway:v1.0` Up with `0.0.0.0:8081->80/tcp`. Both the logs and curl print `Payment Settlement Active`.

---

## 5. Kubernetes [2 Marks]

1. Write `k8s/deployment.yaml`: Deployment `payment-gateway` with `replicas: 2` and `image: nginx:alpine` on port 80. The label `tier: payment` is set on the metadata, the selector and the pod template.
2. Write `k8s/service.yaml`: Service `payment-gateway-svc` of type `NodePort`, labelled `tier: payment`, with selector `tier: payment` and ports `80 → 80`, `nodePort: 30091`.
3. Apply and verify.
   ```powershell
   kubectl config use-context docker-desktop
   kubectl apply -f k8s/
   kubectl rollout status deployment/payment-gateway
   kubectl get all -l tier=payment
   curl.exe http://localhost:30091
   ```
   Output: 2/2 pods Running, plus 1 deployment, 1 replicaset and `service/payment-gateway-svc NodePort 80:30091/TCP`. Curl returns "Welcome to nginx!".
   Note: Docker Desktop Kubernetes runs in "kubeadm" provisioning mode (node `docker-desktop`), which publishes NodePort 30091 on localhost.

---

## 6. IaC — Terraform + Ansible [1 Mark]

1. Write `terraform/main.tf` with the `hashicorp/local` provider and a `local_file.payment_env` resource that writes `payment.env` containing `URL=http://localhost:30091`.
2. Apply it.
   ```powershell
   cd terraform
   terraform init
   terraform apply -auto-approve
   Get-Content payment.env
   ```
   Output: `Apply complete! Resources: 1 added`, and the file contains `URL=http://localhost:30091`.
   (Terraform v1.16.6 on Windows.)
3. Verify with an Ansible ad-hoc command through WSL.
   ```powershell
   wsl -d Ubuntu ansible localhost -i "localhost," -c local -m command -a "cat /mnt/d/devops_lab_practical/terraform/payment.env"
   ```
   Output: `localhost | CHANGED | rc=0 >>` followed by `URL=http://localhost:30091`.
4. `.gitignore` excludes `terraform/.terraform/` and `*.tfstate*`. `payment.env` is committed.
