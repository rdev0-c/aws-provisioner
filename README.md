# MicroK8s AWS Infrastructure Automation

This project provides an automated solution for deploying and managing a MicroK8s Kubernetes cluster on AWS with DNS configuration through Cloudflare. It leverages Infrastructure as Code (IaC) principles using Terraform and Ansible.

## Overview

The automation creates an EC2 instance in AWS, configures DNS in Cloudflare, and installs MicroK8s with several useful Kubernetes services, including FluxCD for GitOps and Podinfo as a sample application. The entire process is orchestrated by a single runner script that coordinates all the necessary components.

## Features

- **One-command deployment**: Create or destroy entire environments with a single command
- **Infrastructure as Code**: All infrastructure managed through Terraform
- **Configuration automation**: MicroK8s and Kubernetes services deployed automatically with Ansible
- **DNS management**: Automatic Cloudflare DNS record creation
- **GitOps ready**: FluxCD installed for Kubernetes-native GitOps workflows
- **Sample application**: Podinfo deployed as a reference service
- **Dependency management**: Automated installation of required dependencies

## Prerequisites

- AWS account with appropriate permissions
- Cloudflare account and zone setup
- AWS CLI configured
- An SSH key pair (`key-name.pem`) stored in `~/.ssh/`

## Dependencies

The project includes an `install-deps.sh` script that automatically installs all necessary dependencies:
- Terraform 1.2+
- Ansible
- jq (JSON processor)

To install dependencies, run:

```bash
./install-deps.sh
```

## AWS Configuration

Create a configuration file in the `conf` directory with the following structure:

```json
{
  "region": "your_region",
  "ami": "your_ami",
  "instance_type": "your_instance_type",
  "key_name": "your_key_name",
  "availability_zone": "your_availability_zone"
}
```

## Cloudflare Configuration

Create a configuration file in the `conf` directory with the following structure:

```json
{
    "cloudflare_zone_id": "your_zone_id",
    "cloudflare_api_token": "your_api_token"
}
```
## Usage

To create a new environment with an instance named "demo":

```bash
./runner.sh -a create --name demo --aws-config aws.config.json --cf-config cloudflare.config.json
```

To destroy the environment:

```bash
./runner.sh -a destroy --name demo --aws-config aws.config.json --cf-config cloudflare.config.json
```

## Components

### Infrastructure (Terraform)

The infrastructure is managed using Terraform and is split into two main components:

AWS Resources:
- VPC with internet gateway
- Public subnet
- Security group with appropriate rules
- EC2 instance with IAM role
- Route tables and associations

Cloudflare DNS:
- DNS A record pointing to the EC2 instance public IP

### Configuration (Ansible)

Ansible handles the software configuration with several roles:
- MicroK8s: Installs MicroK8s and configures it with the necessary services
- FluxCD: Installs FluxCD for GitOps workflows
- Podinfo: A sample application deployed as a Kubernetes resource


### MicroK8s Configuration

MicroK8s is configured with the following add-ons:

- DNS (CoreDNS)
- Host-access
- Ingress controller
- Metrics-server
- RBAC
- Hostpath-storage
- Registry
- Dashboard
- Helm3

Additional plugins can be enabled by modifying the `ansible/roles/common-microk8s/defaults/main.yml` file.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
