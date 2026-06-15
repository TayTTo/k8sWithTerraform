# EKS on Terraform — Key Knowledge & Problems Solved

A working log of the concepts, gotchas, and fixes from building a private EKS cluster
with Terraform, plus official documentation links for each topic. Organized by the
actual problems encountered so you can find a fix fast and learn the concept behind it.

---

## Architecture built

- **VPC** (public + private subnets, single NAT gateway) via `terraform-aws-modules/vpc`
- **EKS** (public + private API endpoint, private nodes) via `terraform-aws-modules/eks`
- **ECR** private repository, nodes pull via the node IAM role
- **Add-ons:** CoreDNS, kube-proxy, VPC CNI (with prefix delegation), Pod Identity agent, EBS CSI driver
- **Istio** ingress gateway
- **Remote state** in S3

---

## 1. Module input types: list vs set

**Problem:** Declared `azs`, `public_subnets`, `private_subnets` as `set(string)`.

**Key point:** The VPC module maps subnets to AZs **by list index** (`count`-based), so
order matters — these must be `list(string)`. A `set` is unordered and gets sorted on
coercion, silently misaligning subnets to AZs.

**Rule of thumb:**
- `count`-based iteration → **list** (order matters)
- `for_each`-based iteration → **set or map** (keys matter)

- Terraform types: https://developer.hashicorp.com/terraform/language/expressions/types
- for_each: https://developer.hashicorp.com/terraform/language/meta-arguments/for_each
- count: https://developer.hashicorp.com/terraform/language/meta-arguments/count

## 2. VPC module — passing CIDR, NAT, and EKS subnet tags

**Problem:** `cidr` variable was declared but never passed to the module (it fell back to
the default `10.0.0.0/16`). Also missing the subnet tags EKS needs for load balancers.

**Key points:**
- Pass `cidr = var.cidr` explicitly.
- `enable_dns_support` + `enable_dns_hostnames` both `true` for EKS.
- Subnet tags for load balancer placement:
  - Public: `kubernetes.io/role/elb = 1`
  - Private: `kubernetes.io/role/internal-elb = 1`
- **NAT gateway** gives private nodes egress — required to pull from ECR, Docker Hub,
  and Helm chart registries.

- VPC module: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
- EKS subnet requirements: https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html
- VPC for EKS: https://docs.aws.amazon.com/eks/latest/userguide/creating-a-vpc.html

## 3. Provider/module version compatibility

**Problem:** Root pinned `aws ~> 6.0`, but unpinned community modules can resolve to a
major built for a different provider generation, breaking `init`/`apply`.

**Key point:** Always pin module versions, and match the major to your AWS provider:
- VPC module `~> 6.0`, EKS module `~> 21.0`, security-group module `~> 6.0` for AWS provider v6.
- The security-group module had a **breaking rewrite**: the old list/named-rule API
  (`ingress_rules = ["all-all"]`, `ingress_with_source_security_group_id`) was replaced
  by a map-based API (`referenced_security_group_id = "self"`, `cidr_ipv4`, `ip_protocol`).

- Version constraints: https://developer.hashicorp.com/terraform/language/expressions/version-constraints
- AWS provider v6 upgrade: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-6-upgrade

## 4. EKS manages its own security groups

**Problem:** Hand-rolled a security-group module with etcd/apiserver/kubelet rules — those
are for **self-managed** Kubernetes, not EKS. Also hit a self-reference cycle (a module
referencing its own output as input).

**Key points:**
- EKS auto-creates a **cluster security group** that allows control-plane↔node traffic.
- The EKS module also creates a **node security group** with baseline rules
  (`create_node_security_group = true` by default).
- You usually don't need a custom SG. Add targeted rules with
  `node_security_group_additional_rules` instead.
- Self-referencing rules use `referenced_security_group_id = "self"` to avoid a dependency cycle.

- EKS SG requirements: https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
- SG module: https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest
- Dependency cycles: https://developer.hashicorp.com/terraform/internals/graph

## 5. Public + private API endpoint

**Key point:** `endpoint_public_access = true` + `endpoint_private_access = true`.
The **public endpoint is AWS-managed** (lives outside your VPC), so enabling it does NOT
make your nodes public. Nodes stay private; your laptop reaches the API over the public path.

- **Lock the public endpoint to your IP** with `endpoint_public_access_cidrs` (a `/32`),
  not `0.0.0.0/0`. This is defense-in-depth on top of IAM auth.

- Endpoint access: https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html

## 6. ECR access from the cluster

**Key point:** The EKS managed node group's IAM role automatically gets
`AmazonEC2ContainerRegistryReadOnly`, so nodes can pull from ECR with no
`imagePullSecrets`. Pulling images = node role; *pushing* images = your own AWS creds.

- ECR pull permissions: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-pull-iam.html
- Pushing to ECR: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html

## 7. Remote state in S3 (bootstrap problem)

**Problem:** `init` failed — the S3 backend bucket didn't exist. Terraform can't create
its own backend bucket (chicken-and-egg).

**Key points:**
- Create the state bucket **first** (CLI `aws s3api create-bucket`, or a small separate
  bootstrap config with local state).
- Backend `region` must match the bucket's actual region, or you get a 403/HTML-parse error.
- Enable bucket **versioning** + **encryption**; block public access.
- S3 backend now has native locking via `use_lockfile = true` (DynamoDB no longer required).

- S3 backend: https://developer.hashicorp.com/terraform/language/backend/s3
- State & backends: https://developer.hashicorp.com/terraform/language/state

## 8. State / reality desync ("already exists" errors)

**Problem:** Resources existed in AWS but not in state (from failed state writes), so
`apply` tried to re-create them → `RepositoryAlreadyExistsException`, etc.

**Key points:**
- Causes: a failed state upload, an interrupted apply (`Ctrl-C`), or acting in the wrong account.
- Fixes: `terraform import` the orphan into state, OR delete the orphan and let Terraform
  recreate it. Choose based on whether the resource holds data worth keeping.
- Check first: `terraform state list` vs. what AWS actually shows.

- import: https://developer.hashicorp.com/terraform/cli/import
- Manipulating state: https://developer.hashicorp.com/terraform/cli/commands/state

## 9. Corporate TLS proxy (Skyhigh) breaking AWS calls

**Problem:** `aws`/Terraform calls failed with `CERTIFICATE_VERIFY_FAILED` or returned
HTML error pages (a `<meta>` XML parse error). A `Via: ... Skyhigh Secure Web Gateway`
header revealed a TLS-inspecting proxy re-signing traffic with its own CA.

**Key points:**
- Add the proxy's root CA to the system trust store (`update-ca-certificates`).
- Point AWS tools at it: `export AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt`.
- Never use `--no-verify-ssl` — it hides exactly the interception you should trust correctly.
- Also seen: a ~60s delay on every AWS call from IMDS probing on a laptop —
  fix with `export AWS_EC2_METADATA_DISABLED=true`.

- AWS CLI cert bundle / proxy: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-proxy.html
- IMDS env var: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html

## 10. New AWS Free Tier — instance type not eligible

**Problem:** Node group failed with `instance type is not eligible for Free Tier`.

**Key points:**
- Accounts created after July 15, 2025 pick a **Free plan** or **Paid plan**; the Free plan
  restricts you to free-tier-eligible instance types (only `t2.micro`/`t3.micro`).
- It is **not a tag or a quota** — it's the account plan. Upgrade Free → Paid (one click,
  irreversible) to launch larger instances like `t3.small`/`t3.medium`.
- EKS runs poorly on micro instances (1 GiB RAM); `t3.small`+ is realistic.

- Free Tier: https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier.html
- AWS Free Tier page: https://aws.amazon.com/free/

## 11. "Too many pods" — VPC CNI IP limit & prefix delegation

**Problem:** Pods stuck `Pending` with `Too many pods` even though CPU/RAM were free.

**Key points:**
- Default VPC CNI gives each pod a VPC IP; pods-per-node is capped by ENI/IP capacity
  (~11 on t3.small, ~4 on t3.micro), **not** by CPU/RAM.
- **Prefix delegation** assigns /28 (16-IP) prefixes per ENI, raising the cap (~110).
  Enable on the `vpc-cni` add-on: `ENABLE_PREFIX_DELEGATION = "true"` with `before_compute = true`.
- `max-pods` is computed by the node at **boot** — you do NOT set a number on AL2023.
- **Nodes must be recycled** to pick up the new cap (existing nodes keep their old value).

- Pods per node / prefix mode: https://docs.aws.amazon.com/eks/latest/best-practices/prefix-mode-linux.html
- VPC CNI: https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html
- Check: `kubectl get nodes -o custom-columns='NAME:.metadata.name,MAX_PODS:.status.allocatable.pods'`

## 12. EKS add-ons & ordering

**Key points:**
- Manage core add-ons through the module's `addons` block: `coredns`, `kube-proxy`,
  `vpc-cni`, `eks-pod-identity-agent`, `aws-ebs-csi-driver`.
- Use `before_compute = true` for `vpc-cni` so its config (e.g. prefix delegation) is in
  place before nodes launch.

- Managing add-ons: https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html

## 13. Helm release name collisions

**Problem:** `cannot reuse a name that is still in use` on repeated `helm install`.

**Key point:** Use `helm upgrade --install <name>` for idempotent installs (updates if it
exists, installs if not). `--wait` blocks until resources are Ready — useful, but it will
block the full timeout if a pod can't start.

- helm upgrade: https://helm.sh/docs/helm/helm_upgrade/

## 14. Istio sidecar-injector webhook blocked (port 15017)

**Problem:** Gateway deployment stuck at `0/1`, no pods created. RS event:
`failed calling webhook "object.sidecar-injector.istio.io" ... context deadline exceeded`.

**Key points:**
- Pod creation calls istiod's **admission webhook**; if the API server can't reach istiod
  on **port 15017**, every pod-create in an injected namespace fails.
- The EKS module's default node SG doesn't open 15017 (a non-standard port). Add it:
  ```hcl
  node_security_group_additional_rules = {
    istio_webhook_15017 = {
      description                   = "Cluster API to node - Istio sidecar injector"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  ```
- Confirm reachability: `kubectl get --raw /api/v1/namespaces/istio-system/services/https:istiod:https-webhook/proxy/inject`
  — a `400 BadRequest` means it's reachable (good); a timeout means still blocked.

- Istio on EKS install: https://istio.io/latest/docs/setup/platform-setup/amazon/
- Admission webhooks: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/
- Istio troubleshooting (injection): https://istio.io/latest/docs/ops/common-problems/injection/

## 15. EBS CSI driver — persistent volumes

**Problem:** Need persistent storage; PVCs would otherwise stay `Pending`.

**Key points:**
- Install the `aws-ebs-csi-driver` add-on **and** give it an IAM role
  (`AmazonEBSCSIDriverPolicy`) via IRSA or Pod Identity — the driver needs permission to
  `CreateVolume`/`AttachVolume`. Attaching the policy to the node role is discouraged.
- Create a **StorageClass** (provisioner `ebs.csi.aws.com`) — the driver doesn't make one.
  Use `volumeBindingMode: WaitForFirstConsumer` so the EBS volume is created in the same
  AZ as the consuming pod (EBS is AZ-locked).
- `gp3` is the current-gen default; the old `kubernetes.io/aws-ebs` provisioner is legacy/in-tree.

- EBS CSI driver: https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
- Driver project: https://github.com/kubernetes-sigs/aws-ebs-csi-driver
- StorageClasses: https://kubernetes.io/docs/concepts/storage/storage-classes/

## 16. IRSA vs Pod Identity (giving pods AWS permissions)

**Key points:**
- Two ways to grant AWS permissions to a Kubernetes service account:
  - **IRSA** (IAM Roles for Service Accounts) — OIDC-based, mature, widely used.
    Module: `terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks`.
  - **EKS Pod Identity** — newer, simpler (uses the `eks-pod-identity-agent` add-on),
    the v21 default direction.
- Both used here: IRSA for the EBS CSI driver role.

- IRSA: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- Pod Identity: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html

## 17. Module scope (variables & references)

**Problem:** `No module call named "ebs_csi_irsa" is declared` / `input variable "tags"
has not been declared`.

**Key point:** A module can only reference things declared in its **own scope**. If a
`module` block lives in root, code inside a child module can't see it — either move the
block into the same module, or pass values across the boundary as input variables.

- Module structure: https://developer.hashicorp.com/terraform/language/modules/develop/structure
- Module sources: https://developer.hashicorp.com/terraform/language/modules/sources

## 18. Cost control (no pause for EKS)

**Key points:**
- EKS **control plane bills continuously** (~$0.10/hr ≈ $73/mo) — there is no pause/stop.
- NAT gateway ~$0.10/hr ≈ $32/mo just for existing.
- To save cost without destroying: scale node group to `desired_size = 0` (kills compute,
  control plane + NAT still bill). To stop all charges: `terraform destroy`, rebuild later.
- Set an **AWS Budgets** alarm so idle clusters don't silently drain credits.
- For your build, the cost-sane habit is **destroy when done, re-apply when needed**.

- EKS pricing: https://aws.amazon.com/eks/pricing/
- AWS Budgets: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html

---

## Quick verification commands

```bash
# Cluster reachable + nodes joined
aws eks update-kubeconfig --name <cluster> --region <region>
kubectl get nodes

# Endpoint mode (want public:true, private:true, cidrs = your IP)
aws eks describe-cluster --name <cluster> --region <region> \
  --query 'cluster.resourcesVpcConfig.{public:endpointPublicAccess,private:endpointPrivateAccess,cidrs:publicAccessCidrs}'

# Nodes are private (publicIp should be null)
aws ec2 describe-instances --region <region> \
  --filters "Name=tag:eks:cluster-name,Values=<cluster>" \
  --query 'Reservations[].Instances[].PublicIpAddress'

# Pods-per-node cap (after prefix delegation + node recycle, ~110)
kubectl get nodes -o custom-columns='NAME:.metadata.name,MAX_PODS:.status.allocatable.pods'

# Core add-ons healthy
kubectl get pods -n kube-system

# Istio webhook reachable (400 = good, timeout = blocked)
kubectl get --raw /api/v1/namespaces/istio-system/services/https:istiod:https-webhook/proxy/inject
```

## Core reference links

- Terraform AWS EKS module: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
- Terraform AWS VPC module: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
- Amazon EKS User Guide: https://docs.aws.amazon.com/eks/latest/userguide/
- eksctl: https://eksctl.io/
- Helm: https://helm.sh/docs/
- Istio: https://istio.io/latest/docs/
