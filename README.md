# Forestracks Pterodactyl Installer
Pterodactyl Panel installer for Forestracks customers.

# Installation:
```
wget https://raw.githubusercontent.com/ForestRacks/pterodactyl-installer/main/install.sh
chmod +x install.sh
./install.sh
```
# Post Installation:
1) Go to http://yourinstall.tld/admin/locations and make a location
2) Go to http://yourinstall.tld/admin/nodes and create your first machine
3) Go to http://yourinstall.tld/admin/nodes/view/1/allocation and add ports for your games
4) Go to http://yourinstall.tld/admin/nodes/view/1/configuration and grab the block of text
5) Then paste the configuration you copied in `/etc/pterodactyl/config.yml` on your machine
6) Lastly, do `systemctl restart wings` and you should be all set

# Troubleshooting common issues:
If you get a mysql error when you run the installer, you mostly ran the installer multiple times and the easiest way of fixing this is reinstalling and running the script again.

# Coming Soon:
1) Cloudflare Proxy option
