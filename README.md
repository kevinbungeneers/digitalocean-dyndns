# Digital Ocean Dynamic DNS

A simple script for updating your DNS records over at Digital Ocean with your current external IP.

## Requirements
This script requires both [doctl](https://github.com/digitalocean/doctl) and [jq](https://stedolan.github.io/jq/) to work its magic.

## Installing

### Download and install script
```
$ curl -O https://raw.githubusercontent.com/kevinbungeneers/digitalocean-dyndns/master/update-dodns.sh
$ chmod +x update-dodns.sh
$ mv update-dodns.sh /usr/local/bin/update-dodns
```

### Create environmentfile
```
$ cat <<EOT >> /etc/default/update-dodns
DO_ACCESSTOKEN="datapikeytho"
DO_DOMAIN="example.com"
DO_HOSTNAME="dathostname"

EOT
```

### Install the systemd service + timer
```
$ ( cd /etc/systemd/system/; curl -O https://raw.githubusercontent.com/kevinbungeneers/digitalocean-dyndns/master/systemd/update-dodns.service && curl -O https://raw.githubusercontent.com/kevinbungeneers/digitalocean-dyndns/master/systemd/update-dodns.timer)
$ systemctl enable update-dodns.timer && systemctl start update-dodns.timer
```

By default the timer gets triggered at 01:00 every night. Change the `OnCalendar` entry in `/etc/systemd/system/update-dodns.timer` if you want a more/less frequent interval.