# Elastic deployment for Kubernetes on baremetal

Deploy ElasticSearch cluster on Kubernetes hosted on baremetal servers.

## Elasticsearch default topology

By default the following number of Elasticsearch nodes are deployed:

* 3 masters
* 2 client for external incoming requests
* 2 data node

## Kubernetes features

The deployment used the following K8S features :

* [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) for data nodes
* On data node a [local-storage persistent volume](https://kubernetes.io/docs/concepts/storage/volumes/#local) is used, it aims to improve ElasticSearch performance by using a local, attached storage, disk
* Discovery is achieved with [Kubernetes plugin for Elasticsearch](https://github.com/fabric8io/elasticsearch-cloud-kubernetes)

The Ansible role has been tested on Kubernetes 1.8

## Security

Elasticsearch can be secured with Searh Guard (see certificates directory)
