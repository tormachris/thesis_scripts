#!/bin/bash

function wait_for_worker {
  while [[ "$(kubectl get nodes | grep Ready | grep none | wc -l)" -lt 1 ]];
  do
    sleep 1
  done
}

function wait_for_podnetwork {
  #podnetwork should be running on the master and at least one worker node
  while [[ "$(kubectl get pods -n kube-system | grep weave-net | grep Running | wc -l)" -lt 2 ]];
  do
    sleep 1
  done
}

#Kubernetes setup
./kubernetes_install.sh

./weavenet_setup.sh

#IP=$(ip addr sh dev $(ip ro sh | grep default | awk '{print $5}') scope global | grep inet | awk '{split($2,addresses,"/"); print addresses[1]}'):6443

IP=$(ifconfig $(route | grep '^default' | grep -o '[^ ]*$') | grep "inet addr:" | awk '{print $2}' | cut -c6-):6443
TOKEN=$(kubeadm token list | tail -n 1 | cut -d ' ' -f 1)
HASH=sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')

(ssh node2 -o "StrictHostKeyChecking no" "bash -s" < ./kubernetes_install.sh true $IP $TOKEN $HASH > /dev/null &)
#ssh node2 kubeadm join $IP --token $TOKEN --discovery-token-ca-cert-hash $HASH
#sleep 60

wait_for_worker

#IP=$(ifconfig eno49 | grep "inet addr:" | awk '{print $2}' | cut -c6-):5000
IP=$(ifconfig $(route | grep '^default' | grep -o '[^ ]*$') | grep "inet addr:" | awk '{print $2}' | cut -c6-):5000
./docker_registry_setup.sh $IP
ssh node2 -o "StrictHostKeyChecking no" "bash -s" < ./docker_registry_setup.sh $IP

