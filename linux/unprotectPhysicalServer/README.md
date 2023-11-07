# Unprotect Physical Servers for Linux

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script removes physical servers from file-based or block-based protection groups.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/linux/unprotectPhysicalServer/unprotectPhysicalServer
# end download commands
```

## Example

```bash
./unprotectPhysicalServer -v mycluster \
                          -u myuser \
                          -d mydomain.net \
                          -s server1.mydomain.net \
                          -s server2.mydomain.net \
                          -l serverlist.txt
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -n, --servername: (optional) name of server to add to the job (use multiple times for multiple)
* -l, --serverlist: (optional) list of server names in a text file (one per line)