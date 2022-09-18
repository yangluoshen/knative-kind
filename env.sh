
export k8sVersion=$(kubectl version --output=yaml | yq '.serverVersion.gitVersion')
export KNATIVE_NET_KOURIER_VERSION=1.7.0
export KNATIVE_VERSION=1.7.1
