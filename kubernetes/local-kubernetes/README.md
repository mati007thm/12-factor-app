# Installing a local Kubernetes environment including control plane and worker nodes

The following setup is run on Ubuntu:

1. Create a file called `containerd-install.sh` on all machines that are to be included in the cluster and fill it with the commands found in the files of this directory
2. Run `chmod u+x ./containerd-install.sh` and the execute it
3. Create a file called `k8s-install.sh` on all machines that are to be included in the cluster and fill it with the commands found in the files of this directory
4. Run `chmod u+x ./k8s-install.sh` and the execute it
5. From the control plane node, please run `sudo kubeadm init`
6. run the following:

    ```shell
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

7. Edit `/etc/containerd/config.toml` file from control plane node `sudo vim /etc/containerd/config.toml` and change the **SystemCgroup** key from **false** to **true** under **plugins** object
8. Restart **containerd** and **kubelet** services:

    ```shell
    sudo service containerd restart
    sudo service kubelet restart
    ```

9. Install the pod network with: `kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml`
10. Make sure to edit the `/etc/containerd/config.toml` file on the worker nodes same as at the control plane!
11. The `kubeadm init` command should also output a `kubeadm join` command. Use this command to join your worker nodes to your cluster.
    1. You may need to run this command as root using `sudo`!
    2. If you missed the command use `kubeadm token create --print-join-command`
12. Install Helm:

    ```shell
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm
    ```

13. Install ingress: `helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx`

Now you are ready to go!
