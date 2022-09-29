#!/bin/bash

set -e

# Pterodactyl Wings Installer 
# Copyright Forestracks 2022

# exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* This script must be executed with root privileges (sudo)." 1>&2
  exit 1
fi

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl is required in order for this script to work."
  echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
  exit 1
fi

# define version using information from GitHub
get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

echo "* Retrieving release information.."
VERSION="$(get_latest_release "pterodactyl/wings")"

echo "* Latest version is $VERSION"

# download URLs
DL_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
CONFIGS_URL="https://raw.githubusercontent.com/ForestRacks/PteroInstaller/master/configs"

COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m'

INSTALL_MARIADB=false

# ufw firewall
CONFIGURE_UFW=false

# firewall_cmd firewall
CONFIGURE_FIREWALL_CMD=false

# SSL (Let's Encrypt)
CONFIGURE_LETSENCRYPT=false
FQDN=""
EMAIL=""

# visual functions
function print_error {
  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

function print_warning {
  COLOR_YELLOW='\033[1;33m'
  COLOR_NC='\033[0m'
  echo ""
  echo -e "* ${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
  echo ""
}

function print_brake {
  for ((n=0;n<$1;n++));
    do
      echo -n "#"
    done
    echo ""
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

# other functions
function detect_distro {
  if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    OS="SuSE"
    OS_VER="?"
  elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS="Red Hat/CentOS"
    OS_VER="?"
  else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
}

function check_os_comp {
  MACHINE_TYPE=$(uname -m)
  if [ "${MACHINE_TYPE}" != "x86_64" ]; then # check the architecture
    print_warning "Detected architecture $MACHINE_TYPE"
    print_warning "Using any other architecture then 64 bit(x86_64) may (and will) cause problems."

    echo -e -n  "* Are you sure you want to proceed? (y/N):"
    read -r choice

    if [[ ! "$choice" =~ [Yy] ]]; then
      print_error "Installation aborted!"
      exit 1
    fi
  fi

  if [ "$OS" == "ubuntu" ]; then
if [ "$OS_VER_MAJOR" == "18" ] || [ "$OS_VER_MAJOR" == "20" ] || [ "$OS_VER_MAJOR" == "22" ]; then
  SUPPORTED=true
else
  SUPPORTED=false
fi
  elif [ "$OS" == "debian" ]; then
    if [ "$OS_VER_MAJOR" == "9" ] || [ "$OS_VER_MAJOR" == "10" ] || [ "$OS_VER_MAJOR" == "11" ]; then
      SUPPORTED=true
    else
      SUPPORTED=false
    fi
  elif [ "$OS" == "centos" ]; then
    if [ "$OS_VER_MAJOR" == "7" ]; then
      SUPPORTED=true
    elif [ "$OS_VER_MAJOR" == "8" ]; then
      SUPPORTED=true
    else
      SUPPORTED=false
    fi
  elif [ "$OS" == "almalinux" ]; then
    if [ "$OS_VER_MAJOR" == "8" ]; then
      SUPPORTED=true
    elif [ "$OS_VER_MAJOR" == "9" ]; then
      SUPPORTED=true
    else
      SUPPORTED=false
    fi
  else
    SUPPORTED=false
  fi

  # exit if not supported
  if [ "$SUPPORTED" == true ]; then
    echo "* $OS $OS_VER is supported."
  else
    echo "* $OS $OS_VER is not supported"
    print_error "Unsupported OS"
    exit 1
  fi

  # check virtualization
  echo -e  "* Installing virt-what..."
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    # silence dpkg output
    export DEBIAN_FRONTEND=noninteractive

    # install virt-what
    DEBIAN_FRONTEND=noninteractive apt -y update -qq
    DEBIAN_FRONTEND=noninteractive apt install -y virt-what -qq

    # unsilence
    unset DEBIAN_FRONTEND
  elif [ "$OS" == "centos" || "$OS" == "almalinux" ]; then
    if [ "$OS_VER_MAJOR" == "7" ]; then
      yum -q -y update

      # install virt-what
      yum -q -y install virt-what
    elif [ "$OS_VER_MAJOR" == "8" ] || [ "$OS_VER_MAJOR" == "9" ]; then
      dnf -y -q update

      # install virt-what
      dnf install -y -q virt-what
    fi
  else
    print_error "Invalid OS."
    exit 1
  fi

  virt_serv=$(virt-what)
  if [ "$virt_serv" != "" ]; then
    print_warning "Virtualization: ${virt_serv//$'\n'/ } detected."
  fi

  if [ "$virt_serv" == "openvz" ] || [ "$virt_serv" == "lxc" ] ; then # add more virtualization types which are not supported
    print_warning "Unsupported type of virtualization detected. Please consult with your hosting provider whether your server can run Docker or not. Proceed at your own risk."
    print_error "Installation aborted!"
    exit 1
  fi

  if uname -r | grep -q "xxxx"; then
    print_error "Unsupported kernel detected."
    exit 1
  fi
}

############################
## INSTALLATION FUNCTIONS ##
############################

letsencrypt() {
  FAILED=false

  # Install certbot
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    DEBIAN_FRONTEND=noninteractive apt install -y snapd
    snap install core; sudo snap refresh core
    snap install --classic certbot
    ln -s /snap/bin/certbot /usr/bin/certbot
  elif [ "$OS" == "centos" ] || [ "$OS" == "almalinux" ]; then
    [ "$OS_VER_MAJOR" == "7" ] && yum install certbot
    [ "$OS_VER_MAJOR" == "8" || "$OS_VER_MAJOR" == "9" ] && dnf install certbot
  else
    # exit
    print_error "OS not supported."
    exit 1
  fi

  # If user has nginx
  systemctl stop nginx || true

  # Obtain certificate
  certbot certonly --no-eff-email --email "$EMAIL" --standalone -d "$FQDN" || FAILED=true

  systemctl start nginx || true

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    print_warning "The process of obtaining a Let's Encrypt certificate failed!"
  fi
  
  # Enable auto-renewal
  (crontab -l ; echo "0 23 * * * certbot renew --quiet --deploy-hook \"systemctl restart wings\" >> /dev/null 2>&1")| crontab -
}

function apt_update {
  DEBIAN_FRONTEND=noninteractive apt update -y
  DEBIAN_FRONTEND=noninteractive apt upgrade -y
}

function install_dep {
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    apt_update

    # install dependencies
    DEBIAN_FRONTEND=noninteractive apt -y install curl
  elif [ "$OS" == "centos" ]; then
    if [ "$OS_VER_MAJOR" == "7" ]; then
      yum -y update

      # install dependencies
      yum -y install curl
    elif [ "$OS_VER_MAJOR" == "8" ] || [ "$OS_VER_MAJOR" == "9" ]; then
      dnf -y update

      # install dependencies
      dnf install -y curl
    fi
  else
    print_error "Invalid OS."
    exit 1
  fi
}

function install_docker {
  echo "* Installing docker .."
  if [ "$OS" == "debian" ]; then
    # install dependencies for Docker
    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt -y install \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg2 \
      software-properties-common

    # get their GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

    # show fingerprint to user
    apt-key fingerprint 0EBFCD88

    # add APT repo
    add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/debian \
      $(lsb_release -cs) \
      stable"

    # install docker
    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt -y install docker-ce docker-ce-cli containerd.io

    # make sure it's enabled & running
    systemctl start docker
    systemctl enable docker

  elif [ "$OS" == "ubuntu" ]; then
    # install dependencies for Docker
    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt -y install \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common

    # get their GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # show fingerprint to user
    apt-key fingerprint 0EBFCD88

    # add APT repo
    sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"

    # install docker
    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt -y install docker-ce docker-ce-cli containerd.io

    # make sure it's enabled & running
    systemctl start docker
    systemctl enable docker

  elif [ "$OS" == "centos" ]; then
    if [ "$OS_VER_MAJOR" == "7" ]; then
      # install dependencies for Docker
      yum install -y yum-utils device-mapper-persistent-data lvm2

      # add repo to yum
      yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo

      # install Docker
      yum install -y docker-ce docker-ce-cli containerd.io
    elif [ "$OS_VER_MAJOR" == "8" ]; then
      # install dependencies for Docker
      dnf install -y dnf-utils device-mapper-persistent-data lvm2

      # add repo to dnf
      dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

      # install Docker
      dnf install -y docker-ce docker-ce-cli containerd.io --nobest
    fi

    # make sure it's enabled & running
    systemctl start docker
    systemctl enable docker

  elif [ "$OS" == "almalinux" ]; then
    if [ "$OS_VER_MAJOR" == "8" || "$OS_VER_MAJOR" == "9" ]; then
      # install dependencies for Docker
      dnf install -y dnf-utils device-mapper-persistent-data lvm2

      # add repo to dnf
      dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

      # install Docker
      dnf install -y docker-ce docker-ce-cli containerd.io --nobest
    fi

    # make sure it's enabled & running
    systemctl start docker
    systemctl enable docker
  fi

  echo "* Docker has now been installed."
}

function ptdl_dl {
  echo "* Installing Pterodactyl Wings .. "

  mkdir -p /etc/pterodactyl
  curl -L -o /usr/local/bin/wings "$DL_URL"

  chmod u+x /usr/local/bin/wings

  echo "* Done."
}

function systemd_file {
  echo "* Installing systemd service.."
  curl -o /etc/systemd/system/wings.service $CONFIGS_URL/wings.service
  systemctl daemon-reload
  systemctl enable wings
  echo "* Installed systemd service!"
}

function install_mariadb {
  if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
    DEBIAN_FRONTEND=noninteractive apt update && apt install mariadb-server -y
  elif [ "$OS" == "centos" ] || [ "$OS" == "almalinux" ]; then
    [ "$OS_VER_MAJOR" == "7" ] && curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
    [ "$OS_VER_MAJOR" == "7" ] && yum -y install mariadb-server
    [ "$OS_VER_MAJOR" == "8" || "$OS_VER_MAJOR" == "9" ] && dnf install -y mariadb mariadb-server
  else
    print_error "Unsupported OS for MariaDB installations!"
  fi
  systemctl enable mariadb
  systemctl start mariadb
}

#################################
##### OS SPECIFIC FUNCTIONS #####
#################################

function firewall_ufw {
  apt update
  DEBIAN_FRONTEND=noninteractive apt install ufw -y

  echo -e "\n* Enabling Uncomplicated Firewall (UFW)"
  echo "* Opening port 22 (SSH), 8080 (Daemon Port), 2022 (Daemon SFTP Port)"

  # pointing to /dev/null silences the command output
  ufw allow ssh > /dev/null
  ufw allow 80 comment "certbot requires to generate" > /dev/null
  ufw allow 8080 comment "pterodactyl wings" > /dev/null
  ufw allow 2022 comment "pterodactyl sftp" > /dev/null

  [ "$CONFIGURE_LETSENCRYPT" == true ] && ufw allow http > /dev/null
  [ "$CONFIGURE_LETSENCRYPT" == true ] && ufw allow https > /dev/null

  ufw enable
  ufw status numbered | sed '/v6/d'
}

function firewall_firewalld {
  echo -e "\n* Enabling firewall_cmd (firewalld)"
  echo "* Opening port 22 (SSH), 8080 (Daemon Port), 2022 (Daemon SFTP Port)"

  # Install
  [ "$OS_VER_MAJOR" == "7" ] && yum -y -q update
  [ "$OS_VER_MAJOR" == "7" ] && yum -y -q install firewalld > /dev/null
  [ "$OS_VER_MAJOR" == "8" ] && dnf -y -q update
  [ "$OS_VER_MAJOR" == "8" ] && dnf -y -q install firewalld > /dev/null

  # Enable
  systemctl --now enable firewalld > /dev/null # Enable and start

  # Configure
  firewall-cmd --add-port 8080/tcp --permanent -q # Port 8080
  firewall-cmd --add-port 2022/tcp --permanent -q # Port 2022
  [ "$CONFIGURE_LETSENCRYPT" == true ] && firewall-cmd --add-port 80/tcp --permanent -q # Port 80
  [ "$CONFIGURE_LETSENCRYPT" == true ] && firewall-cmd --add-port 443/tcp --permanent -q # Port 443

  firewall-cmd --permanent --zone=trusted --change-interface=pterodactyl0 -q
  firewall-cmd --zone=trusted --add-masquerade --permanent
  firewall-cmd --ad-service=ssh --permanent -q # Port 22
  firewall-cmd --reload -q # Enable firewall

  echo "* Firewall-cmd installed"
  print_brake 70
}

####################
## MAIN FUNCTIONS ##
####################
function perform_install {
  echo "* Installing pterodactyl wings.."
  [ "$CONFIGURE_UFW" == true ] && firewall_ufw
  [ "$CONFIGURE_FIREWALL_CMD" == true ] && firewall_firewalld
  install_dep
  install_docker
  ptdl_dl
  systemd_file
  [ "$INSTALL_MARIADB" == true ] && install_mariadb
  [ "$CONFIGURE_LETSENCRYPT" == true ] && letsencrypt

  # return true if script has made it this far
  return 0
}

ask_letsencrypt() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    print_warning "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk (if port 80/443 is closed, the script will fail)!"
  fi

  print_warning "You cannot use Let's Encrypt with your hostname as an IP address! It must be a FQDN (e.g. node.example.org)."

  echo -e -n "* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): "
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
  fi
}

function main {
  # check if we can detect an already existing installation
  if [ -d "/etc/pterodactyl" ]; then
    print_warning "The script has detected that you already have Pterodactyl wings on your system! You cannot run the script multiple times, it will fail!"
    echo -e -n "* Are you sure you want to proceed? (y/N): "
    read -r CONFIRM_PROCEED
    if [[ ! "$CONFIRM_PROCEED" =~ [Yy] ]]; then
      print_error "Installation aborted!"
      exit 1
    fi
  fi

  # detect distro
  detect_distro

  # checks if the system is compatible with this installation script
  check_os_comp

  print_brake 70

  echo "* "
  echo "* The installer will install Docker, required dependencies for Wings"
  echo "* as well as Wings itself. But it's still required to create the node"
  echo "* on the panel and then place the configuration file on the node manually after"
  echo "* the installation has finished. Read more about this process on the"
  echo "* official documentation: $(hyperlink 'https://pterodactyl.io/wings/1.0/installing.html#configure-daemon')"
  echo "* "
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: this script will not start Wings automatically (will install systemd service, not start it)."
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: this script will not enable swap (for docker)."
  print_brake 42

  echo -e "* ${COLOR_RED}Note${COLOR_NC}: If you installed the Pterodactyl panel on the same machine, do not use this option or the script will fail!"
  echo -n "* Would you like to install MariaDB (MySQL) server on the daemon as well? (y/N): "

  read -r CONFIRM_INSTALL_MARIADB
  [[ "$CONFIRM_INSTALL_MARIADB" =~ [Yy] ]] && INSTALL_MARIADB=true

  # UFW is available for Ubuntu/Debian
  if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    echo -e -n "* Do you want to automatically configure UFW (firewall)? (y/N): "
    read -r CONFIRM_UFW

    if [[ "$CONFIRM_UFW" =~ [Yy] ]]; then
      CONFIGURE_UFW=true
    fi

    # Available for Debian 9/10
    if [ "$OS" == "debian" ]; then
      if [ "$OS_VER_MAJOR" == "9" ] || [ "$OS_VER_MAJOR" == "10" ] || [ "$OS_VER_MAJOR" == "11" ]; then
        ask_letsencrypt
      fi
    fi

    # Available for Ubuntu 18/20/22
    if [ "$OS" == "ubuntu" ]; then
      if [ "$OS_VER_MAJOR" == "18" ] || [ "$OS_VER_MAJOR" == "20" ] || [ "$OS_VER_MAJOR" == "22" ]; then
        ask_letsencrypt
      fi
    fi
  fi

  # Firewall-cmd is available for CentOS
  if [ "$OS" == "centos" ] || [ "$OS" == "almalinux" ]; then
    echo -e -n "* Do you want to automatically configure firewall-cmd (firewall)? (y/N): "
    read -r CONFIRM_FIREWALL_CMD

    if [[ "$CONFIRM_FIREWALL_CMD" =~ [Yy] ]]; then
      CONFIGURE_FIREWALL_CMD=true
    fi

    ask_letsencrypt
  fi

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    while [ -z "$FQDN" ]; do
        echo -n "* Set the FQDN to use for Let's Encrypt (node.example.com): "
        read -r FQDN

        ASK=false

        [ -z "$FQDN" ] && print_error "FQDN cannot be empty"
        [ -d "/etc/letsencrypt/live/$FQDN/" ] && print_error "A certificate with this FQDN already exists!" && FQDN="" && ASK=true

        [ "$ASK" == true ] && echo -e -n "* Do you still want to automatically configure HTTPS using Let's Encrypt? (y/N): "
        [ "$ASK" == true ] && read -r CONFIRM_SSL

        if [[ ! "$CONFIRM_SSL" =~ [Yy] ]] && [ "$ASK" == true ]; then
          CONFIGURE_LETSENCRYPT=false
          FQDN="none"
        fi
    done
  fi

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    # set EMAIL
    while [ -z "$EMAIL" ]; do
        echo -n "* Enter email address for Let's Encrypt: "
        read -r EMAIL

        [ -z "$EMAIL" ] && print_error "Email cannot be empty"
    done
  fi

  echo -n "* Proceed with installation? (y/N): "

  read -r CONFIRM
  [[ "$CONFIRM" =~ [Yy] ]] && perform_install && return

  print_error "Installation aborted"
  exit 0
}

function goodbye {
  echo ""
  print_brake 70
  echo "* Wings installer completed"
  echo "*"
  echo "* To continue, you need to configure Wings to run with your panel"
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: Refer to the post installation steps now $(hyperlink 'https://github.com/ForestRacks/PteroInstaller#post-installation')"
  echo "*"
  print_brake 70
  echo ""
}

# run script
main
goodbye
