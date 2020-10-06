## Bind 9 Docker Image

This image is a simple way to configure a DNS Bind server.

This image is prepared for simple use. It helps me a lot when I need to do some tests that need DNS resolution.

Of course, this is a Bind server and can be used in production, if desired. Remember to mount the correct files to avoid problems.

### Build Image

```
docker build . -t bind9:11-own
```

### Configuration
This image has been configured to have configuration files in the '/opt/named/conf.d', '/ opt / named / zones' and '/ opt / named / data' paths.

The '/opt/named/conf.d' must have all the configuration files (.conf) that need to be loaded on the Bind server.
The '/ opt / named / zones' must have the zone configuration files (.zone) that you need to configure. Zone files must be configured using the path '/ opt / named / data /'
The '/ opt / named / data' must have zone files.

Well, using the docker you can mount any type of file. If you create your own named.conf, set the variable "NAME_CONF_EDITED" to a value of 1. The init script finds the files in '/ opt / named' and uses the 'include' statements to load them. This variable (NAMED_CONF_EDITED) disables this.

In the [Example](#Example) section you can get a better idea of how this works.

### Variables

The variables bellow help a configure the Bind server to test purposes. You can use in others environments, but I have sure that you will need a lot more configuration.

DEBUG_LEVEL (default 0) - Debug level of bind. High numbers produce more verbose log

NAMED_CONF_EDITED (default 0) - Define if the script to start named will do the replaces and includes

IPV4_PORT (default 53) - Port IPV4 to listen 

IPV6_PORT (default 53) - Port IPV6 to listen

IPV4_LISTEN_ACL (default 127.0.0.1) - Listen IPV4 address. Need specified the semicolon after the address. If have more than one put in the same line using semicolon to separate them.

IPV6_LISTEN_ACL (default ::1) - Listen IPV6 address. Need specified the semicolon after the address. If have more than one put in the same line using semicolon to separate them.

ALLOW_QUERY (default localhost) - Address or ranges permited to do queries. Need specified the semicolon after the address. If have more than one put in the same line using semicolon to separate them.

RECURSION (default yes) - If recursion parameter will be activate or not

DNSSEC_ENABLE (default yes) - If dnssec will be enable

DNSSEC_VALIDATION (default yes) - If dnssec-validation parameter will be activate

DNSSEC_LOOKASIDE (default auto) - If dnssec-lookaside will be activate (should be)

START_PARAMS (default -fg -d ${DEBUG_LEVEL}) - Parameters to initialize named service

### Examples

In this example we will start up a Bind server that allow dynamic updates.

```
##### Creating the directories to bind the files
mkdir -p /tmp/named/{data,conf.d,zones,rndc}

##### Files to permit Dynamic Update
##### Controls statement in named.conf
cat << EOF > /tmp/named/conf.d/controls.conf
controls {
  inet * port 953
  allow { localnets; } keys { update_key; }; // be the must restrictive possible in acls
};
EOF

##### Keys statement in named.conf
cat << EOF > /tmp/named/conf.d/update_key.conf
key update_key {
     algorithm "hmac-sha256";
     secret
       "c3Ryb25nIGVub3VnaCBmb3IgYSBtYW4gYnV0IG1hZGUgZm9yIGEgd29tYW4K";
};
EOF

##### Zone conf file
cat << EOF > /tmp/named/zones/example.com.zone
zone "example.com" {
     type master;
     file "/opt/named/data/example.com.db";
     
    update-policy {
        grant update_key zonesub ANY;
     };
};
EOF

##### Zone file with DNS entries
cat << EOF > /tmp/named/data/example.com.db
\$ORIGIN example.com.
\$TTL 1H
@ IN SOA dns.example.com. admin.example.com. (
                                        0       ; serial
                                        6H      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        30M )   ; minimum
        NS      dns
dns     A       127.0.0.1
www     A       192.168.7.14
EOF

##### The 25 is Bind user ID
chown -R 25:25 /tmp/named/data
```

#### Start the container
The acl using 'localnets;' allow any host in the same network where Bind is running. You can use an acl file in conf.d directory or specified a range in this parameter ('172.16.0.0/12;').
We are bind the ports 1053 to 53 (dns) and 1953 to 953 (rndc).
```
docker run -d --name bind9 -e DEBUG_LEVEL=1 -e IPV4_LISTEN_ACL='localnets;' -e ALLOW_QUERY='localnets;' -v /tmp/named:/opt/named -p 1053:53/udp -p 1053:53/tcp -p 1953:953 bind9:11-own
```

#### Testing Dynamic Update
```
##### Creating the directory
mkdir -p /tmp/ddns

##### rndc configuration
cat << EOF > /tmp/ddns/rndc.conf
key update_key {
  algorithm "hmac-sha256";
  secret
    "c3Ryb25nIGVub3VnaCBmb3IgYSBtYW4gYnV0IG1hZGUgZm9yIGEgd29tYW4K";
};

options {
     default-server 127.0.0.1;
     default-port   1953; // docker bind port 1953 to 953
     default-key    update_key;
};
EOF

##### nsupdate conf
cat << EOF > /tmp/ddns/ns.conf
key update_key {
  algorithm "hmac-sha256";
  secret
    "c3Ryb25nIGVub3VnaCBmb3IgYSBtYW4gYnV0IG1hZGUgZm9yIGEgd29tYW4K";
};
EOF
```

#### Updating the zone
We can use nsupdate to just updates hosts in zone or use rndc to control the Bind server.

##### nsupdate
```
nsupdate -k /tmp/ddns/ns.conf
```
After the command a prompt will be open. Cut and paste the follow entry:
```
server 127.0.0.1 1053
update add archlinux.example.com 86400 A 192.168.100.100
send
answer
quit
```

Look if the answer is 'NOERROR' in output. Now get the host with nslookup command:
```
nslookup -port=1053 archlinux.example.com 127.0.0.1
```

##### rndc
rndc -c /tmp/ddns/rndc.conf zonestatus example.com

###### sync zone
cat /tmp/named/data/example.com.db
rndc -c /tmp/ddns/rndc.conf sync example.com
cat /tmp/named/data/example.com.db

###### Status
rndc -c /tmp/ddns/rndc.conf status