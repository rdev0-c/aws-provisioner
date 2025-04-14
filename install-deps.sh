#!/bin/bash
# install_ansible_terraform.sh
# Script to install Ansible, Terraform, and jq (if not already installed)

echo "Starting installation of required tools..."

# Detect OS
if [ -f /etc/os-release ]; then
    # Linux
    . /etc/os-release
    OS=$NAME
    ID=$ID
    VERSION=$VERSION_ID
elif [ "$(uname)" == "Darwin" ]; then
    # macOS
    OS="macOS"
else
    echo "Unsupported operating system"
    exit 1
fi

echo "Detected OS: $OS (ID: $ID)"

# Install Ansible
echo "Installing Ansible..."

case $ID in
    "ubuntu"|"debian")
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo apt-add-repository --yes --update ppa:ansible/ansible
        sudo apt-get install -y ansible
        ;;
    "rhel"|"centos")
        if [ -x "$(command -v dnf)" ]; then
            sudo dnf install -y ansible
        else
            sudo yum install -y epel-release
            sudo yum install -y ansible
        fi
        ;;
    "fedora")
        sudo dnf install -y ansible
        ;;
    *)
        if [ "$OS" == "macOS" ]; then
            if [ -x "$(command -v brew)" ]; then
                brew install ansible
            else
                echo "Homebrew not found. Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew install ansible
            fi
        else
            echo "Unsupported OS for Ansible installation: $OS"
            exit 1
        fi
        ;;
esac

# Install Terraform
echo "Installing Terraform..."

case $ID in
    "ubuntu"|"debian")
        sudo apt-get update
        sudo apt-get install -y gnupg software-properties-common curl
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update
        sudo apt-get install -y terraform
        ;;
    "rhel"|"centos")
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        sudo yum -y install terraform
        ;;
    "fedora")
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
        sudo dnf -y install terraform
        ;;
    *)
        if [ "$OS" == "macOS" ]; then
            if [ -x "$(command -v brew)" ]; then
                brew tap hashicorp/tap
                brew install hashicorp/tap/terraform
            else
                echo "Homebrew not found. Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew tap hashicorp/tap
                brew install hashicorp/tap/terraform
            fi
        else
            echo "Unsupported OS for Terraform installation: $OS"
            exit 1
        fi
        ;;
esac

# Check and install jq if not already installed
if ! command -v jq &> /dev/null; then
    echo "jq not found. Installing jq..."
    
    case $ID in
        "ubuntu"|"debian")
            sudo apt-get install -y jq
            ;;
        "rhel"|"centos")
            if [ -x "$(command -v dnf)" ]; then
                sudo dnf install -y jq
            else
                sudo yum install -y jq
            fi
            ;;
        "fedora")
            sudo dnf install -y jq
            ;;
        *)
            if [ "$OS" == "macOS" ]; then
                if [ -x "$(command -v brew)" ]; then
                    brew install jq
                else
                    echo "Homebrew not found. Installing Homebrew first..."
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                    brew install jq
                fi
            else
                echo "Unsupported OS for jq installation: $OS"
            fi
            ;;
    esac
else
    echo "jq is already installed. Skipping installation."
fi

# Verify installations
echo "Verifying installations..."
echo "Ansible version:"
ansible --version
echo "Terraform version:"
terraform --version
echo "jq version:"
jq --version

echo "Installation completed!"