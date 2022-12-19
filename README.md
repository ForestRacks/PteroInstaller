# ForestRacks Pterodactyl Installer
Pterodactyl Panel installer for Forestracks customers. This installer works on both Ubuntu and CentOS. Please carefully read all options for the best experience.

## Installation:
1) Reinstall your machine if you changed anything before you run the installer.
2) Point a DNS A-Record to your machine IP like panel.forestracks.com to 192.168.53.72
3) Download and run installer:
```
bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/Production/install.sh)
```
## Post Installation:
* Please note "example.com" refers to the panel URL you set during the installation process.
1) Go to http://example.com/admin/nodes/view/1/allocation and add ports for your games

## Troubleshooting:
1) If you get a "-bash: curl: command not found" error, run `apt install curl` on Debian based linux distributions or `yum install curl` on RHEL based distributions.
2) If you get a mysql connection error when you run the installer, you mostly ran the installer multiple times. The easiest way of fixing this is reinstalling your OS and running the install script again.
3) If you get Let's Encrypt SSL generation errors, you might be using an IP address as your FQDN and Let's Encrypt only generates SSLs for domains or you could be trying to generate an SSL for a FQDN that doesn't have an A-Record pointing to your machine IP address.

## Supported Operating Systems
* Ubuntu: 18.04, 20.04, 21.04, 22.04
* CentOS: 7, 8
* AlmaLinux: 8, 9
* Debian: 9, 10, 11

## Contributors ✨

Created and maintained by:
1) [Zinidia](https://github.com/Zinidia)
2) [Vilhelm Prytz](https://github.com/vilhelmprytz)
3) [ImGreen](https://github.com/GreenDiscord)
3) [Neon](https://github.com/DeveloperNeon)
4) [sam1370](https://github.com/sam1370)
5) [Linux123123](https://github.com/Linux123123)
