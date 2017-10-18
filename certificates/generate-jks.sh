#! /bin/bash
#set -ex
set -e

function usage() {
  echo Usage: `basename $0` cert_directory logging_namespace_in_openshift elastic_namespace_in_kubernetes 1>&2
}

function generate_JKS_chain() {
    dir=${SCRATCH_DIR:-_output}
    ADD_OID=$1
    NODE_NAME=$2
    CERT_NAMES=${3:-$NODE_NAME}
    ks_pass=${KS_PASS:-kspass}
    ts_pass=${TS_PASS:-tspass}
    rm -rf $NODE_NAME

    extension_names=""
    for name in ${CERT_NAMES//,/ }; do
        extension_names="${extension_names},dns:${name}"
    done

    if [ "$ADD_OID" = true ]; then
        extension_names="${extension_names},oid:1.2.3.4.5.5"
    fi

    echo Generating keystore and certificate for node $NODE_NAME

    keytool -genkey \
        -alias     $NODE_NAME \
        -keystore  $dir/$NODE_NAME.jks \
        -keypass   $ks_pass \
        -storepass $ks_pass \
        -keyalg    RSA \
        -keysize   2048 \
        -validity  3650 \
        -dname "CN=$NODE_NAME, OU=OpenShift, O=Logging" \
        -ext san=dns:localhost,ip:127.0.0.1"${extension_names}"

    echo Generating certificate signing request for node $NODE_NAME

    keytool -certreq \
        -alias      $NODE_NAME \
        -keystore   $dir/$NODE_NAME.jks \
        -storepass  $ks_pass \
        -file       $dir/$NODE_NAME.csr \
        -keyalg     rsa \
        -dname "CN=$NODE_NAME, OU=OpenShift, O=Logging" \
        -ext san=dns:localhost,ip:127.0.0.1"${extension_names}"

    echo Sign certificate request with CA

    openssl ca \
        -in $dir/$NODE_NAME.csr \
        -notext \
        -out $dir/$NODE_NAME.crt \
        -config $dir/signing.conf \
        -extensions v3_req \
        -batch \
        -extensions server_ext

    echo "Import back to keystore (including CA chain)"

    keytool  \
        -import \
        -file $dir/ca.crt  \
        -keystore $dir/$NODE_NAME.jks   \
        -storepass $ks_pass  \
        -noprompt -alias sig-ca

    keytool \
        -import \
        -file $dir/$NODE_NAME.crt \
        -keystore $dir/$NODE_NAME.jks \
        -storepass $ks_pass \
        -noprompt \
        -alias $NODE_NAME

    echo All done for $NODE_NAME
}

function generate_JKS_client_cert() {
    NODE_NAME="$1"
    ks_pass=${KS_PASS:-kspass}
    ts_pass=${TS_PASS:-tspass}
    dir=${SCRATCH_DIR:-_output}  # for writing files to bundle into secrets

    echo Generating keystore and certificate for node ${NODE_NAME}

    keytool -genkey \
        -alias     $NODE_NAME \
        -keystore  $dir/$NODE_NAME.jks \
        -keyalg    RSA \
        -keysize   2048 \
        -validity  3650 \
        -keypass $ks_pass \
        -storepass $ks_pass \
        -dname "CN=$NODE_NAME, OU=OpenShift, O=Logging"

    echo Generating certificate signing request for node $NODE_NAME

    keytool -certreq \
        -alias      $NODE_NAME \
        -keystore   $dir/$NODE_NAME.jks \
        -file       $dir/$NODE_NAME.jks.csr \
        -keyalg     rsa \
        -keypass $ks_pass \
        -storepass $ks_pass \
        -dname "CN=$NODE_NAME, OU=OpenShift, O=Logging"

    echo Sign certificate request with CA
    openssl ca \
        -in "$dir/$NODE_NAME.jks.csr" \
        -notext \
        -out "$dir/$NODE_NAME.jks.crt" \
        -config $dir/signing.conf \
        -extensions v3_req \
        -batch \
        -extensions server_ext

    echo "Import back to keystore (including CA chain)"

    keytool  \
        -import \
        -file $dir/ca.crt  \
        -keystore $dir/$NODE_NAME.jks   \
        -storepass $ks_pass  \
        -noprompt -alias sig-ca

    keytool \
        -import \
        -file $dir/$NODE_NAME.jks.crt \
        -keystore $dir/$NODE_NAME.jks \
        -storepass $ks_pass \
        -noprompt \
        -alias $NODE_NAME

    echo All done for $NODE_NAME
}

function join { local IFS="$1"; shift; echo "$*"; }

function createTruststore() {

  echo "Import CA to truststore for validating client certs"

  keytool  \
    -import \
    -file $dir/ca.crt  \
    -keystore $dir/truststore.jks   \
    -storepass $ts_pass  \
    -noprompt -alias sig-ca
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

dir=$1
SCRATCH_DIR=$dir
PROJECT=${2} # project name in Openshift, usually "logging"
ELASTIC_PROJECT=${3} # Namespace where elasticsearch is deployed on Kubernetes

touch $dir/ca.db

echo "Generating admin certificate for SearchGuard + ElasticSearch"
if [[ ! -f $dir/system.admin.jks || -z "$(keytool -list -keystore $dir/system.admin.jks -storepass kspass | grep sig-ca)" ]]; then
  generate_JKS_client_cert "system.admin"
fi

echo "Generating elasticsearch.jks (SSL - Transport /etc/elasticsearch/secret/searchguard.key in the ElasticSearch container)"
if [[ ! -f $dir/elasticsearch.jks || -z "$(keytool -list -keystore $dir/elasticsearch.jks -storepass kspass | grep sig-ca)" ]]; then
  generate_JKS_chain true elasticsearch "elasticsearch-discovery.${ELASTIC_PROJECT}.svc.cluster.local, elasticsearch.${ELASTIC_PROJECT}.svc.cluster.local, elasticsearch-data.${ELASTIC_PROJECT}.svc.cluster.local, $(join , logging-es{,-ops})"
fi

echo "Generating logging-es.jks (SSL - HTTP /etc/elasticsearch/secret/key in the ElasticSearch container)"
if [[ ! -f $dir/logging-es.jks || -z "$(keytool -list -keystore $dir/logging-es.jks -storepass kspass | grep sig-ca)" ]]; then
  generate_JKS_chain false logging-es "elasticsearch-discovery.${ELASTIC_PROJECT}.svc.cluster.local, elasticsearch.${ELASTIC_PROJECT}.svc.cluster.local, elasticsearch-data.${ELASTIC_PROJECT}.svc.cluster.local, $(join , logging-es{,-ops}{,-cluster}{,.${PROJECT}.svc.cluster.local})"
fi

[ ! -f $dir/truststore.jks ] && createTruststore

# necessary so that the job knows it completed successfully

read -p "Do you want to copy generated files into Ansible ssl role files ? [y/n]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  cp -i -v $dir/elasticsearch.jks ../roles/elastic/files/searchguard.key
  cp -i -v $dir/truststore.jks ../roles/elastic/files/searchguard.truststore
  cp -i -v $dir/logging-es.jks ../roles/elastic/files/logging-es.jks
  cp -i -v $dir/system.admin.jks ../roles/elastic/files/system.admin.jks
fi

exit 0
