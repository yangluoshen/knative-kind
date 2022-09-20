#!/usr/bin/env bash

set -eo pipefail

reg_name='kind-registry'
reg_port='5000'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    -v /mnt/registry:/var/lib/registry \
    registry:2
fi

kindVersion=$(kind version);
K8S_VERSION=${k8sVersion:-v1.25.0}
KIND_BASE=${KIND_BASE:-kindest/node}
CLUSTER_NAME=${KIND_CLUSTER_NAME:-knative}
KIND_VERSION=${KIND_VERSION:-v0.14}

echo "KinD version is ${kindVersion}"
if [[ ! $kindVersion =~ "${KIND_VERSION}." ]]; then
  echo "WARNING: Please make sure you are using KinD version ${KIND_VERSION}.x, download from https://github.com/kubernetes-sigs/kind/releases"
  echo "For example if using brew, run: brew upgrade kind"
  read -p "Do you want to continue on your own risk? Y/n: " REPLYKIND </dev/tty
  if [ "$REPLYKIND" == "Y" ] || [ "$REPLYKIND" == "y" ] || [ -z "$REPLYKIND" ]; then
    echo "You are very brave..."
    sleep 2
  elif [ "$REPLYKIND" == "N" ] || [ "$REPLYKIND" == "n" ]; then
    echo "Installation stopped, please upgrade kind and run again"
    exit 0
  fi
fi

REPLY=continue
KIND_EXIST="$(kind get clusters -q | grep ${CLUSTER_NAME} || true)"
if [[ ${KIND_EXIST} ]] ; then
 read -p "Knative Cluster kind-${CLUSTER_NAME} already installed, delete and re-create? N/y: " REPLY </dev/tty
fi
if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
  kind delete cluster --name ${CLUSTER_NAME}
elif [ "$REPLY" == "N" ] || [ "$REPLY" == "n" ] || [ -z "$REPLY" ]; then
  echo "Installation skipped"
  exit 0
fi

echo "Using image ${KIND_BASE}:${K8S_VERSION}"
# create a cluster with the local registry enabled in containerd
KIND_CLUSTER=$(mktemp)
cat <<EOF | kind create cluster --name ${CLUSTER_NAME} --wait 120s --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: ${KIND_BASE}:${K8S_VERSION}
  extraPortMappings:
  - containerPort: 31080 # expose port 31380 of the node to port 80 on the host, later to be use by kourier or contour ingress
    listenAddress: 127.0.0.1
    hostPort: 80
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:${reg_port}"]
EOF

# connect the registry to the cluster network if not already connected
if [ "$(docker inspect -f="{{json .NetworkSettings.Networks.kind}}" "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
