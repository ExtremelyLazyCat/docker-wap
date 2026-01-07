First: rename the correct docker-compose-*.yaml to
docker-compose.yaml depending on your Osmocom setup. If
you have the stack setup natively (no Docker) on your
system, you will want to rename
docker-compose-local.yaml to docker-compose.yaml. If
you are using @Rhees's image for the URAN-1 with Docker,
rename docker-compose-uran1.yaml to docker-compose.yaml.
```
mv docker-compose-local.yaml docker-compose.yaml
```
OR
```
mv docker-compose-uran1.yaml docker-compose.yaml
```

Next: build the image.
```
docker compose build
```

NOTE: if you get an error regarding a Bad Gateway, just
wait a minute then retry the command. One of the servers
where a patch is hosted seems to be a little finicky

Next, you are going to need to configure Mbuni, Kannel,
and Osmocom. I'll start by connecting osmo-sgsn to the
patched osmo-ggsn in this Docker image.
The config file for osmo-sgsn is normally located at:
*URAN-1 Docker Folder*/osmocom/osmo-sgsn.cfg
for those using @Rhees's docker image, or:
/etc/osmocom/osmo-sgsn.cfg
for those running Osmocom natively.
```
nano /path/to/osmo-sgsn.cfg
```

CHANGE: 
```
ggsn 0 remote-ip X.X.X.X 
```
TO:
```
ggsn 0 remote-ip 172.20.0.14
```

CHANGE:
```
gtp local-ip X.X.X.X
```
TO:
```
gtp local-ip 172.20.0.1
```
You will also need to make sure your auth-policy in
osmo-sgsn is set to remote. This will grab the associated
MSISDN for each PDP context creation from osmo-hlr, which
is needed by osmo-ggsn to send IP/MSISDN info to Mbuni.

CHANGE/ADD:
```
auth-policy remote
```
under "sgsn".

Next, setup osmo-msc's SMPP so WAP Push messages can be
delivered to mobiles on your network.
The config file for osmo-msc is normally located at:
*URAN-1 Docker Folder*/osmocom/osmo-msc.cfg
for those using @Rhees's docker image, or:
/etc/osmocom/osmo-msc.cfg
for those running Osmocom natively.
```
nano /path/to/osmo-msc.cfg
```

ADD:
```
smpp
 local-tcp-ip 0.0.0.0 2775
 policy accept-all
```

If you are running Osmocom natively, you will also need
to configure Kannel so osmo-msc can be reached by
Kannel's bearerbox. Kannel's config file is located at:
*docker-wap directory*/wap/kannel/kannel.conf
```
nano wap/kannel/kannel.conf
```

Under "group = smsc", CHANGE:
```
host = 172.20.0.6
```
TO:
```
host = 172.20.0.1
```

If you are running Osmocom natively, you will also need
to allow SMPP traffic from the Docker container to reach
reach your local system with osmo-msc. This can be done
with an iptables rule:
```
sudo iptables -A INPUT -i wap-bridge -j ACCEPT
```

Note that iptables rules do not persist between reboots,
so you will have to run this command every reboot or find
a way to make the rule persistent (iptables-save).

Restart the Osmocom programs to save the config changes.
If you are running Osmocom natively, this can be done by:
```
sudo systemctl restart osmo-sgsn osmo-msc
```
Or if you are running @Rhees's docker image:
```
docker restart docker-sgsn-1 docker-msc-1
```
And now lets spin up the MMS Gateway! :
```
docker compose up -d
```
