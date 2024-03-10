#!/bin/bash

set -e

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/main.sh
  source <(curl -sSL "$GIT_REPO_URL"/lib/main.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# exit with error status code if user is not root
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
  ubuntu | debian)
    install_packages "dnsutils" true
    ;;
  rocky | almalinux)
    install_packages "bind-utils" true
    ;;
  esac

  return 0
}

dns_verify() {
  output "Resolving DNS for $fqdn"
  ip=$(curl -4 -s https://ip.forestracks.net)
  dns_record=$(dig +short @9.9.9.9 "$fqdn" | tail -n1)
  [ "${ip}" != "${dns_record}" ] && fail
  output "DNS verified!"
}

main() {
  fqdn="$1"
  dep_install
  dns_verify
  true
}

main "$1" "$2"