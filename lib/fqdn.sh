#!/bin/bash

set -e

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/main.sh
  source /tmp/main.sh || source <(curl -fsSL "$GIT_REPO_URL"/lib/main.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

CHECKIP_URL="https://ip.forestracks.net"
DNS_SERVER="9.9.9.9"

# Exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* This script must be executed with root privileges (sudo)." 1>&2
  exit 1
fi

fail() {
  output "The DNS record ($dns_record) does not match your server IP. Please make sure the FQDN $fqdn is pointing to the IP of your server, $ip"
  output "If you are using Cloudflare, please disable the proxy or opt out from Let's Encrypt."

  echo -n "* Proceed anyways (your install will be broken if you do not know what you are doing)? (y/N): "
  read -r override

  [[ ! "$override" =~ [Yy] ]] && error "Invalid FQDN or DNS record" && exit 1
  return 0
}

dep_install() {
  update_repos true

  case "$OS" in
  debian | ubuntu)
    install_packages "dnsutils" true
    ;;
  almalinux | rocky)
    install_packages "bind-utils" true
    ;;
  esac

  return 0
}

confirm() {
  output "This script will perform a HTTPS request to the endpoint $CHECKIP_URL"
  output "The official IP check service for this script, https://ip.forestracks.net"
  output "- The reason is to check if your domain properly resolves to this system's IP."
  output "- We will store request logs for several days for DDoS Mitigation reasons."
  output "- Requests may also be logged by Cloudflare and other transit providers."
  output "If you would like to use another service, modify the CHECKIP_URL env var."

  echo -e -n "* I agree that this HTTPS request is performed (y/N): "
  read -r confirm
  [[ "$confirm" =~ [Yy] ]] || (error "User did not agree" && false)
}

dns_verify() {
  output "Resolving DNS for $fqdn"
  ip=$(curl -4 -s $CHECKIP_URL)
  dns_record=$(dig +short @$DNS_SERVER "$fqdn" | tail -n1)
  [ "${ip}" != "${dns_record}" ] && fail
  output "DNS verified!"
}

main() {
  fqdn="$1"
  confirm || exit 1
  dep_install
  dns_verify
  true
}

main "$1" "$2"
