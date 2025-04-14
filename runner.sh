#!/bin/bash

# Default values
ACTION=""
INSTANCE_NAME=""
DOMAIN_NAME=""
AWS_CONFIG_NAME=""
CF_CONFIG_NAME=""

# Getting the base directory of the project
BASE_DIR="$(pwd)"
CONF_DIR="${BASE_DIR}/conf"

# Displaying usage information
function show_usage {
    echo "Usage: $0 -a [create|destroy] --name [instance-name] [options]"
    echo ""
    echo "Options:"
    echo "  -a, --action ACTION        Required. Action to perform (create or destroy)"
    echo "  --name INSTANCE_NAME       Required for create. Name for the instance"
    echo "  --aws-config CONFIG_NAME   AWS configuration file in conf directory"
    echo "  --cf-config CONFIG_NAME    Cloudflare configuration file in conf directory"
    echo "  -h, --help                 Show this help message"
    echo ""
    exit 1
}

# Parsing command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -a|--action)
      ACTION="$2"
      shift 2
      ;;
    --name)
      INSTANCE_NAME="$2"
      shift 2
      ;;
    --aws-config)
      AWS_CONFIG_NAME="$2"
      shift 2
      ;;
    --cf-config)
      CF_CONFIG_NAME="$2"
      shift 2
      ;;
    -h|--help)
      show_usage
      ;;
    *)
      echo "Unknown parameter: $1"
      show_usage
      ;;
  esac
done

# Validating required parameters
if [[ -z "$ACTION" ]]; then
  echo "Error: Action (-a) is required. Use 'create' or 'destroy'."
  show_usage
fi

# Handling different actions
if [[ "$ACTION" != "create" && "$ACTION" != "destroy" ]]; then
  echo "Error: Invalid action '$ACTION'. Use 'create' or 'destroy'."
  show_usage
fi

# Checking if the AWS config is already a full path
if [[ "$AWS_CONFIG_NAME" == /* ]]; then
  AWS_CONFIG_FILE="$AWS_CONFIG_NAME"
else
  AWS_CONFIG_FILE="${CONF_DIR}/${AWS_CONFIG_NAME}"
fi

# Checking if the Cloudflare config is already a full path
if [[ "$CF_CONFIG_NAME" == /* ]]; then
  CF_CONFIG_FILE="$CF_CONFIG_NAME"
else
  CF_CONFIG_FILE="${CONF_DIR}/${CF_CONFIG_NAME}"
fi

echo "Using AWS config file: $AWS_CONFIG_FILE"
echo "Using Cloudflare config file: $CF_CONFIG_FILE"

# Navigating to the terraform AWS directory
cd "${BASE_DIR}/terraform/aws" || exit

# Reading values from the AWS JSON config files
AMI=$(jq -r '.ami' "$AWS_CONFIG_FILE")
INSTANCE_TYPE=$(jq -r '.instance_type' "$AWS_CONFIG_FILE")
KEY_NAME=$(jq -r '.key_name' "$AWS_CONFIG_FILE")
AVAILABILITY_ZONE=$(jq -r '.availability_zone' "$AWS_CONFIG_FILE")
REGION=$(jq -r '.region' "$AWS_CONFIG_FILE")
SSH_INGRESS_CIDR="0.0.0.0/0"

# Reading values from the Cloudflare config file
ZONE_ID=$(jq -r '.cloudflare_zone_id' "$CF_CONFIG_FILE")
API_TOKEN=$(jq -r '.cloudflare_api_token' "$CF_CONFIG_FILE")
CF_EMAIL=$(jq -r '.cloudflare_email' "$CF_CONFIG_FILE" 2>/dev/null || echo "")
CF_API_KEY_GLOBAL=$(jq -r '.cloudflare_api_key_global' "$CF_CONFIG_FILE" 2>/dev/null || echo "")

# Setting default name tag for destroy operations
if [[ -z "$INSTANCE_NAME" ]]; then
  NAME_TAG="MicroK8s"
else
  NAME_TAG="$INSTANCE_NAME"
fi

if [[ "$ACTION" == "destroy" ]]; then
  echo "Destroying infrastructure..."
  
  # Destroying Cloudflare DNS record
  cd "${BASE_DIR}/terraform/cloudflare" || exit
  
  if terraform state list | grep -q 'cloudflare_record'; then
      echo "Existing Cloudflare DNS record found. Destroying..."
      terraform destroy -auto-approve -var="dns_record_name=null" -var="ip_address=0.0.0.0" -var="cloudflare_zone_id=$ZONE_ID" -var="cloudflare_api_token=$API_TOKEN"
  else
      echo "No existing Cloudflare DNS record found."
  fi
  
  # Destroying AWS instance
  cd "${BASE_DIR}/terraform/aws" || exit
  
  if terraform state list | grep -q 'aws_instance'; then
      echo "Existing machine found. Destroying..."
      terraform destroy -auto-approve \
        -var="ami=$AMI" \
        -var="instance_type=$INSTANCE_TYPE" \
        -var="key_name=$KEY_NAME" \
        -var="availability_zone=$AVAILABILITY_ZONE" \
        -var="region=$REGION" \
        -var="ssh_ingress_cidr=$SSH_INGRESS_CIDR" \
        -var="name_tag=$NAME_TAG"
  else
      echo "No existing machine found."
  fi
  
  echo "Infrastructure destroyed successfully."
  exit 0
fi

# "create" action error handling
if [[ "$ACTION" == "create" && -z "$INSTANCE_NAME" ]]; then
  echo "Error: Instance name (--name) is required for create action."
  show_usage
fi

# Checking if there is an existing machine
if terraform state list | grep -q 'aws_instance'; then
    echo "Existing machine found. Destroying..."
    terraform destroy -auto-approve -var="ami=$AMI" -var="instance_type=$INSTANCE_TYPE" -var="key_name=$KEY_NAME" -var="availability_zone=$AVAILABILITY_ZONE" -var="region=$REGION" -var="ssh_ingress_cidr=$SSH_INGRESS_CIDR" -var="name_tag=$NAME_TAG"
else
    echo "No existing machine found."
fi

echo "Running terraform init and validating configuration..."
terraform init && terraform validate

# Running terraform apply for AWS
echo "Applying changes..."
terraform apply -auto-approve -var="ami=$AMI" -var="instance_type=$INSTANCE_TYPE" -var="key_name=$KEY_NAME" -var="availability_zone=$AVAILABILITY_ZONE" -var="region=$REGION" -var="ssh_ingress_cidr=$SSH_INGRESS_CIDR" -var="name_tag=$NAME_TAG"

# Capturing the public IP and making it a variable
PUBLIC_IP=$(terraform output -json public_ip | jq -r '.')

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "null" ]; then
    echo "Error: Failed to get public IP from AWS instance"
    exit 1
fi

echo "Instance deployed with public IP: $PUBLIC_IP"

# Navigating to the Cloudflare directory
cd "${BASE_DIR}/terraform/cloudflare" || exit

# Checking if the Cloudflare DNS record exists
if terraform state list | grep -q 'cloudflare_record'; then
    echo "Existing Cloudflare DNS record found. Destroying..."
    terraform destroy -auto-approve -var="dns_record_name=$INSTANCE_NAME" -var="ip_address=$PUBLIC_IP" -var="cloudflare_zone_id=$ZONE_ID" -var="cloudflare_api_token=$API_TOKEN" -target=cloudflare_record.dns
else
    echo "No existing Cloudflare DNS record found."
fi

echo "Running terraform init and validating configuration..."
terraform init && terraform validate

# Using the instance name for the DNS record name
echo "Setting up DNS record: $INSTANCE_NAME.rdevapp.org pointing to $PUBLIC_IP"

# Running terraform apply for Cloudflare DNS
echo "Applying Cloudflare DNS changes..."
terraform apply -auto-approve -var="dns_record_name=$INSTANCE_NAME" -var="ip_address=$PUBLIC_IP" -var="cloudflare_zone_id=$ZONE_ID" -var="cloudflare_api_token=$API_TOKEN"

# Capturing the full domain and making it a variable
DOMAIN=$(terraform output -json dns_record | jq -r '.')

if [ -z "$DOMAIN" ] || [ "$DOMAIN" == "null" ]; then
    echo "Error: Failed to get DNS record from Cloudflare"
    exit 1
fi

# Ensuring the Ansible inventory directory exists
mkdir -p "${BASE_DIR}/ansible/inventory"

# Generating Ansible inventory file
echo "Generating Ansible inventory file..."
cat <<EOF > "${BASE_DIR}/ansible/inventory/inventory.ini"
[ec2_instances]
$PUBLIC_IP ansible_ssh_user=ubuntu ansible_ssh_private_key_file=~/.ssh/demo-key.pem domain=$DOMAIN
EOF

# Waiting for the instance to be reachable via SSH
echo "Waiting for the instance to be reachable via SSH..."
TIMEOUT=300  # Timeout duration in seconds
INTERVAL=10  # Interval between checks in seconds
ELAPSED=0

while ! ssh -o StrictHostKeyChecking=no -i ~/.ssh/demo-key.pem ubuntu@$PUBLIC_IP "exit" 2>/dev/null; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "Timeout reached. The instance is not reachable via SSH."
        exit 1
    fi
    echo "Instance not reachable yet. Waiting..."
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

# Running Ansible playbook
echo "Running Ansible playbook..."
cd "${BASE_DIR}/ansible/playbook" || { echo "Failed to change directory to playbook"; exit 1; }
ansible-playbook playbook.yml -e "domain=$DOMAIN cloudflare_email=$CF_EMAIL cloudflare_api_token=$API_TOKEN cloudflare_api_key_global=$CF_API_KEY_GLOBAL cloudflare_zone_id=$ZONE_ID"

# Checking if the Ansible playbook ran successfully
if [ $? -eq 0 ]; then
    echo "Deployment completed successfully!"
    echo "Instance Name: $INSTANCE_NAME"
    echo "Domain: $DOMAIN"
    echo "Public IP: $PUBLIC_IP"
else
    echo "Ansible playbook failed. Please check the output for errors."
    exit 1
fi