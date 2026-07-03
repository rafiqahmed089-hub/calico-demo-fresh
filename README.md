cat > README.md <<'EOF'
# Calico CNI Network Policy Demo

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.28+-blue.svg)](https://kubernetes.io/)
[![Calico](https://img.shields.io/badge/Calico-v3.26-orange.svg)](https://www.projectcalico.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive hands-on demonstration of Calico CNI network policies in Kubernetes, implementing a zero-trust security model for a 3-tier application.

![Architecture](docs/architecture-diagram.png)

## 🎯 Overview

This project demonstrates how to:
- Install and configure Calico CNI in Kubernetes
- Implement network segmentation using NetworkPolicies
- Apply zero-trust security principles
- Test and validate network policies
- Monitor and troubleshoot network connectivity

## 🏗️ Architecture

┌──────────────────────────────────────────────┐
│          Calico CNI Network Layer            │
└──────────────────────────────────────────────┘
│
┌─────────────┼─────────────┐
│             │             │
┌───▼────┐   ┌────▼────┐   ┌────▼─────┐
│Frontend│   │ Backend │   │ Database │
│ nginx  │──►│http-echo│──►│  redis   │
│  :80   │   │  :8080  │   │  :6379   │
└────────┘   └─────────┘   └──────────┘
✅            ✅             ❌
ALLOWED      ALLOWED       BLOCKED
# Advanced: View Calico Resources
# Install calicoctl if not already installed
curl -L https://github.com/projectcalico/calico/releases/download/v3.26.1/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl
chmod +x /usr/local/bin/calicoctl

# Set environment for calicoctl
export DATASTORE_TYPE=kubernetes
export KUBECONFIG=~/.kube/config

# View Calico network policies
calicoctl get networkpolicy -n calico-demo -o wide

# View workload endpoints
calicoctl get workloadendpoint -n calico-demo

# View IP pools
calicoctl get ippool -o wide

