This is a playground for a mixed kubernetes cluster of ubuntu and windows nodes wrapped in a vagrant environment.

**CAVEAT** This uses kubeadm which only supports a single master node.

# Usage

Install `kubectl` in your machine, e.g. on Ubuntu:

```bash
wget -qO- https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
add-apt-repository "deb http://apt.kubernetes.io/ $(lsb_release -cs) main"
apt-get install -y kubectl
kubectl version --client
```

Or on a mac with [Homebrew](https://brew.sh)

```bash
brew install kubernetes-cli
```

Launch a kubernetes master (`km1`), a ubuntu worker (`kwu1`) and a windows worker (`kww1`):

```bash
vagrant up km1 kwu1 kww1
```

These three VMs are the default. You can simply run:

```bash
vagrant up
```

# Kubernetes proxy

Launch the kubernetes api server proxy in background:

```bash
export KUBECONFIG=$PWD/tmp/admin.conf
kubectl proxy &
```

Then access the kubernetes dashboard at:

    http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

select `Token` and use the token from the `tmp/admin-token.txt` file.

# Kubernetes Basics Condensed Tutorial

**NB** See the full [Kubernetes Basics tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/).

Install httpie:

```bash
apt-get install -y httpie
```

Launch an example Deployment and wait for it to be up:

```bash
kubectl run kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1 --port=8080
kubectl rollout status deployment kubernetes-bootcamp
```

Access it by http through the kubernetes proxy:

```bash
export POD_NAME=$(kubectl get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep kubernetes-bootcamp-)
echo Name of the Pod: $POD_NAME
http http://localhost:8001/api/v1/namespaces/default/pods/$POD_NAME/proxy/ # this accesses an http endpoint inside the pod.
```

Execute a command inside the pod:

```bash
kubectl exec $POD_NAME env
kubectl exec $POD_NAME -- curl --verbose --silent localhost:8080
```

Launch an interactive shell inside the pod:

```bash
kubectl exec -ti $POD_NAME bash
```

Show information about the pod:

```bash
kubectl describe pod $POD_NAME
```

Expose the pod as a kubernetes Service that can be accessed at any kubernetes node:

```bash
kubectl expose deployment kubernetes-bootcamp --type NodePort --port 8080
kubectl get services
kubectl describe service kubernetes-bootcamp
```

Access the Service through the `kw1` worker node:

```bash
export NODE_PORT=$(kubectl get service kubernetes-bootcamp -o go-template='{{(index .spec.ports 0).nodePort}}')
echo NODE_PORT=$NODE_PORT
http http://10.11.0.201:$NODE_PORT
```

Create multiple instances (aka replicas) of the application:

```bash
kubectl scale deployments/kubernetes-bootcamp --replicas=4
kubectl rollout status deployment kubernetes-bootcamp
kubectl get deployments
kubectl get pods -o wide
kubectl describe deployment kubernetes-bootcamp
kubectl describe service kubernetes-bootcamp
```

And access the Service multiple times to see the request being handled by different containers:

```bash
http http://10.11.0.201:$NODE_PORT
http http://10.11.0.201:$NODE_PORT
http http://10.11.0.201:$NODE_PORT
```

Upgrade the application version:

```bash
kubectl set image deployment kubernetes-bootcamp kubernetes-bootcamp=jocatalin/kubernetes-bootcamp:v2
kubectl rollout status deployment kubernetes-bootcamp # wait for rollout.
kubectl describe pods # see the image.
http http://10.11.0.201:$NODE_PORT # hit it again, now to see v=2.
```

Remove the application:

```bash
kubectl delete deployment kubernetes-bootcamp
kubectl delete service kubernetes-bootcamp
kubectl get all
```

Destroy the Vagrant vms:

```bash
vagrant destroy kww1 kwu1 km1
```

This will prompt you to ask if it is ok to do so.

Or destroy all of them without asking:

```bash
vagrant destroy -f
```

# Reference

* [flannel plugin](https://github.com/containernetworking/plugins/tree/master/plugins/meta/flannel)
* [Kubernetes on Windows](https://docs.microsoft.com/en-us/virtualization/windowscontainers/kubernetes/getting-started-kubernetes-windows)
* [Intro to Windows support in Kubernetes](https://kubernetes.io/docs/setup/windows/intro-windows-in-kubernetes/)
* [Kubernetes 1.14: Production-level support for Windows Nodes, Kubectl Updates, Persistent Local Volumes GA](https://kubernetes.io/blog/2019/03/25/kubernetes-1-14-release-announcement/)
* [Windows containers now supported in Kubernetes
](https://cloudblogs.microsoft.com/opensource/2019/03/25/windows-server-containers-now-supported-kubernetes/)
* [Introducing: Kubernetes Overlay Networking for Windows](https://techcommunity.microsoft.com/t5/Networking-Blog/Introducing-Kubernetes-Overlay-Networking-for-Windows/ba-p/363082)
