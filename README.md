# ForestRacks Pterodactyl Installer
Pterodactyl Panel installer for Forestracks customers. This installer works on both Ubuntu and CentOS. Please carefully read all options for the best experience.

## Installation:
1) Reinstall your machine if you changed anything before you run the installer.
2) Point a DNS A-Record to your machine IP like YourFQDN.TLD to 127.0.0.1
3) Download and run installer:
```
wget https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install.sh
chmod +x install.sh
./install.sh
```
## Post Installation:
* Note - YourFQDN.TLD refers to the panel URL you set during the installation process.
1) Go to http://YourFQDN.TLD/admin/locations and make a location
2) Go to http://YourFQDN.TLD/admin/nodes and create your first machine
3) Go to http://YourFQDN.TLD/admin/nodes/view/1/allocation and add ports for your games
4) Go to http://YourFQDN.TLD/admin/nodes/view/1/configuration and click auto-deploy "Generate Token" button on the right.
5) Then run the command it gives you on your machine's command line.
6) Lastly, do `systemctl restart wings` and then you are done!

## Troubleshooting:
1) If you get a mysql connection error when you run the installer, you mostly ran the installer multiple times. The easiest way of fixing this is reinstalling your OS and running the install script again.
2) If you get Let's Encrypt SSL generation errors, you might be using an IP address as your FQDN and Let's Encrypt only generates SSLs for domains or you could be trying to generate an SSL for a FQDN that doesn't have an A-Record pointing to your machine IP address.

## Supported Operating Systems
* Ubuntu: 18.04, 20.04, 21.04, 22.04
* CentOS: 7.9, 8.6
* Debian: 9, 10, 11

## Contributors ✨

Created and maintained by:
1) [Zinidia](https://github.com/Zinidia)
2) [Neon](https://github.com/DeveloperNeon)
3) [Vilhelm Prytz](https://github.com/vilhelmprytz)
4) [sam1370](https://github.com/sam1370)
5) [Linux123123](https://github.com/Linux123123)
