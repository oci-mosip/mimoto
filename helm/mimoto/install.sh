#!/bin/bash
# Installs mimoto service
## Usage: ./install.sh [kubeconfig]

if [ $# -ge 1 ] ; then
  export KUBECONFIG=$1
fi

NS=mimoto
MIMOTO_CHART_VERSION=0.12.0

echo Create $NS namespace
#kubectl create ns $NS #The namespace mimoto already created during partner-onboarder setup

function installing_mimoto() {
  echo Istio label
  kubectl label ns $NS istio-injection=enabled --overwrite
  helm repo add mosip https://mosip.github.io/mosip-helm
  helm repo update

  echo Copy configmaps
  sed -i 's/\r$//' copy_cm.sh
  ./copy_cm.sh

  echo Copy secrets
  sed -i 's/\r$//' copy_secrets.sh
  ./copy_secrets.sh

  ENABLE_INSECURE=''
  # ENABLE_INSECURE='--set enable_insecure=true';


  echo  "Copy secrets to config-server namespace"
  ./copy_cm_func.sh secret mimoto-wallet-binding-partner-api-key mimoto config-server
  ./copy_cm_func.sh secret mimoto-oidc-partner-clientid mimoto config-server

  echo Updating mimoto-oidc-keystore-password value
  ./copy_cm_func.sh secret mimoto-oidc-keystore-password mimoto config-server

  kubectl -n config-server set env --keys=mimoto-wallet-binding-partner-api-key --from secret/mimoto-wallet-binding-partner-api-key deployment/config-server --prefix=SPRING_CLOUD_CONFIG_SERVER_OVERRIDES_
  kubectl -n config-server set env --keys=mimoto-oidc-partner-clientid --from secret/mimoto-oidc-partner-clientid deployment/config-server --prefix=SPRING_CLOUD_CONFIG_SERVER_OVERRIDES_
  kubectl -n config-server set env --keys=mimoto-oidc-keystore-password --from secret/mimoto-oidc-keystore-password deployment/config-server --prefix=SPRING_CLOUD_CONFIG_SERVER_OVERRIDES_

  kubectl -n config-server rollout restart deployment config-server
  kubectl -n config-server rollout status deployment config-server

  echo Installing mimoto
  helm -n $NS install mimoto mosip/mimoto --version $MIMOTO_CHART_VERSION $ENABLE_INSECURE

  kubectl -n $NS  get deploy -o name |  xargs -n1 -t  kubectl -n $NS rollout status

  echo Installed mimoto

  return 0
}

# set commands for error handling.
set -e
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errtrace  # trace ERR through 'time command' and other functions
set -o pipefail  # trace ERR through pipes
installing_mimoto   # calling function
