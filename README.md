# EKS on AWS with Terraform: dev, qa and prd

This project builds a Kubernetes cluster on AWS (Amazon EKS) using Terraform. It builds three
separate copies: **dev**, **qa** and **prd**. Each copy can be built and removed on its own
without affecting the others.

Everything is written as code. Nothing is created by hand in the AWS console.

Region: `af-south-1`. Names follow one pattern, for example `trimm-st-eks-dev`,
`trimm-st-eks-qa` and `trimm-st-eks-prd`.

## What gets built (per environment)

- A few network subnets, taken from the address range assigned to this project
- Two access roles: one for the cluster, one for its servers
- The EKS cluster (the part that manages Kubernetes)
- A group of servers (the "node group") that run the applications
- One firewall rule so the test web page can be reached

## How the project is organised

```
.
├── main.tf, variables.tf, outputs.tf, providers.tf   # the main entry point
├── modules/capitec_eks/    # the shared recipe for building a cluster
├── envs/
│   ├── dev/   dev.tfvars   dev.tfbackend
│   ├── qa/    qa.tfvars    qa.tfbackend
│   └── prd/   prd.tfvars   prd.tfbackend
├── bootstrap/state-backend/   # creates the storage buckets (option B below)
├── scripts/                   # optional helper scripts
├── k8s/nginx.yaml             # a small test web server
└── .github/workflows/         # automation
```

**Why it is set up this way.** The building instructions are written once, in the shared
recipe (the module). Each environment is just two small files:

- a **`.tfvars` file** that says how big that environment should be
- a **`.tfbackend` file** that says where that environment keeps its records

Because every command points at one environment's files, it is always clear which environment
you are changing. Nothing specific to an environment is written into the shared recipe, and
every setting is checked for sensible values before anything is built.

### How the environments differ

| | dev | qa | prd |
|---|---|---|---|
| Availability zones | 2 | 2 | 3 |
| Servers (min / max / starting) | 1 / 2 / 1 | 1 / 3 / 2 | 2 / 4 / 3 |
| Server size | t3.small | t3.small | t3.small |

## Where Terraform keeps its records (remote state)

Terraform writes down everything it builds. This record is called the **state**. Here:

- The state is stored in AWS S3, not on your laptop.
- Each environment has its **own bucket and its own state file**, so they can never mix:
  `trimm-st-s3-dev`, `trimm-st-s3-qa` and `trimm-st-s3-prd`.
- State **locking** is turned on, so two people cannot change the same environment at once.
- The buckets keep old versions and are encrypted and private.

**The chicken-and-egg problem.** Terraform needs the bucket to exist before it can start, so
it cannot create the bucket for itself. The buckets are therefore created once, up front,
using one of these options:

```bash
# Option A: a short script
./scripts/create-state-buckets.sh trimm-st af-south-1

# Option B: Terraform with a temporary local record
cd bootstrap/state-backend
terraform init
terraform apply -var="prefix=trimm-st"
```

## How to build an environment

You need Terraform 1.10 or newer, the AWS CLI with working credentials, and kubectl.

Replace `dev` with `qa` or `prd` as needed. Always use the **same environment** in both places.

```bash
terraform init -reconfigure -backend-config=envs/dev/dev.tfbackend
terraform plan  -var-file=envs/dev/dev.tfvars
terraform apply -var-file=envs/dev/dev.tfvars
```

- `init` connects Terraform to that environment's records.
- `plan` shows what will be built, without building it.
- `apply` builds it.

Run `init` again whenever you switch environments. Plan will not run without a `-var-file`;
this is deliberate, so you always choose the environment on purpose.

There is also an optional helper, `./scripts/tf.sh dev plan`, that picks the right files for you.

## How to check it works

```bash
aws eks update-kubeconfig --name trimm-st-eks-dev --region af-south-1
kubectl get nodes                       # the server should say Ready
kubectl apply -f k8s/nginx.yaml         # start a test web server
kubectl get nodes -o wide               # note the EXTERNAL-IP
curl http://<EXTERNAL-IP>:30007         # you should see the nginx welcome page
```

## How to remove an environment

```bash
kubectl delete -f k8s/nginx.yaml
terraform destroy -var-file=envs/dev/dev.tfvars
```

This removes everything that environment created. The storage buckets are kept, because they
only hold the records. Delete them separately when the whole project is finished.

## Choices, assumptions and limits

- **Shared network.** The training account gives each learner a block of addresses
  (`172.31.148.0/22` here). We build our subnets inside it, and each environment gets its own
  slice so they do not overlap.
- **Servers are on the public internet side.** There is no NAT gateway, which keeps the cost low.
  A real production setup would normally use private subnets.
- **The test port is open to everyone.** Port 30007 accepts traffic from anywhere so the nginx demo
  can be reached. For anything real, limit it to trusted addresses in the `.tfvars` file.
- **Automatic scaling.** The starting number of servers is set in code, but later changes by an
  autoscaler are left alone, so Terraform does not undo them.
- **Server size.** `t2.small` would not start in this region, so we use `t3.small`.
- **Who can use the cluster.** Whoever creates the cluster becomes its administrator. Anyone else
  needs to be added to the cluster's access list.
- **No secrets in the code.** AWS credentials come from your own login, never from files in this
  project.
