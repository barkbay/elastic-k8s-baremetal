# Elastic deployment for Kubernetes on baremetal

Deploy ElasticSearch cluster on Kubernetes hosted on baremetal servers.

## Elasticsearch default topology

By default the following number of Elasticsearch nodes are deployed:

* 3 masters
* 2 clients for external incoming requests
* 2 data nodes

The number of replicas can be set in the inventory.

## Kubernetes features

The deployment uses the following K8S features:

* [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) for data and master nodes
* On data and master nodes, [local-storage persistent volumes](https://kubernetes.io/docs/concepts/storage/volumes/#local) are used; it aims to improve ElasticSearch performance by using a local, attached storage, disk
* Discovery is achieved with [Kubernetes plugin for Elasticsearch](https://github.com/fabric8io/elasticsearch-cloud-kubernetes)
* [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) can be set in the Elasticsearch namespace
* Different User IDs can be defined for each kind of node (RunAsUser)
* The Elasticsearch public node port can be specified in the inventory

The Ansible role has been tested on Kubernetes 1.9.

## Security

Elasticsearch can be secured with Search Guard (see certificates directory).
