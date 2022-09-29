#!/bin/bash

set -e

# Pterodactyl Installer 
# Copyright ForestRacks 2022

# exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* This script must be executed with root privileges (sudo)." 1>&2
  exit 1
fi

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* Installing dependencies."
  # RHEL / CentOS / etc
  if [ -n "$(command -v yum)" ]; then
    yum update -y >> /dev/null 2>&1
    yum -y install curl >> /dev/null 2>&1
  fi
  if [ -n "$(command -v apt-get)" ]; then
    DEBIAN_FRONTEND=noninteractive apt update -y >> /dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends snapd cron curl gzip >> /dev/null 2>&1
  fi
  # Check if curl was installed
  if ! [ -x "$(command -v curl)" ]; then
    echo "* curl is required in order for this script to work."
    echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
    exit 1
  fi
fi

output() {
  echo "* ${1}"
}

error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}
basic=false
standard=false
advanced=false

panel=false
wings=false

output "Pterodactyl installation script"
output "This script is not associated with the official Pterodactyl Project. PteroInstaller comes with ABSOLUTELY NO WARRANTY, to the extent permitted by applicable law."
output
output "DISCLAIMER: This installer may not work as intended on all environments. Please reinstall your machine if you need to rerun the script because rerunning it could have unintended consequences."

output

while [ "$basic" == false ] && [ "$standard" == false ] && [ "$advanced" == false ]; do
  output "What installation mode would you like to use?"
  output "[1] Basic Installer - Install the panel and wings on your IP with very few prompts."
  output "[2] Standard installer - Install the panel and wings with prompts for an FQDN and SSL."
  output "[3] Advanced installer - Install either the panel or wings with options like mail configuration"

  echo -n "* Input 1-3: "
  read -r action

  case $action in
    1 )
      basic=true ;;
    2 )
      standard=true ;;
    3 )
      advanced=true ;;
    * )
      error "Invalid option" ;;
  esac
done

if [ "$basic" == false ] && [ "$standard" == false ]; then
  while [ "$panel" == false ] && [ "$wings" == false ]; do
    output "What would you like to do?"
    output "[1] Install the panel (Web Dashboard)"
    output "[2] Install the wings (Machine Daemon)"
    output "[3] Install both on the same machine"

    echo -n "* Input 1-3: "
    read -r action

    case $action in
      1 )
        panel=true ;;
      2 )
        wings=true ;;
      3 )
        panel=true
        wings=true ;;
      * )
        error "Invalid option" ;;
    esac
  done

  [ "$panel" == true ] && bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install-panel.sh)
  [ "$wings" == true ] && bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install-wings.sh)
elif [ "$standard" == true ]; then
  bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install-standard.sh)
else
  bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install-basic.sh)
fi
