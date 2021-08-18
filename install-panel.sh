# Pterodactyl Installer 
# Copyright Forestracks 2021
set -e

# Check if user is root
if [[ $EUID -ne 0 ]]; then
  echo "* This script must be executed with root privileges (sudo)." 1>&2
  exit 1
fi

# Check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "The script has detected that curl hasnt been installed"
  echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
  exit 1
fi

