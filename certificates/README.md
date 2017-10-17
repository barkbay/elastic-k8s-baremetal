The script ```generate-jks.sh``` generates all the *.jks needed to run a secured Elasticsearch with SearchGuard

1. First you have to generate your own certificate authority, I use the Openshift client tool but you can use your favorite pki tool :
```
oc adm ca create-signer-cert \
  --key=ca.key --cert=ca.crt --serial=ca.serial.txt \
  --name=logging-signer --expire-days=3650
```

2. Generate the JKS files :
```
$ ./generate-jks.sh . logging elastic1
```

CREDITS : The Openshift Team https://github.com/openshift/openshift-ansible
