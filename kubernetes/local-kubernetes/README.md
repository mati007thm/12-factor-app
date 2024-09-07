# Installing a local Kubernetes environment including control plane and worker nodes

The following setup is run on Ubuntu 24.04 LTS:

- Control-Plane: 2 CPUs, 4 GiB Memory and 12 GiB SSD Storage
- Worker Nodes: 4 CPUs, 7,5 GiB Memory and 50 GiB SSD Storage

1. Make sure the firewall allows the following inbound on the control plane as well as all outbound traffic:
   1. SSH - port 22 so that we can ssh from our local machine to control plane
   2. TCP - port 6443 for API server that can be access by anyone
   3. TCP -port range 2379–2380 for etcd database server client API on the private network only
   4. TCP -port range 10250–10259 for kubelet, kube-scheduler, and kube-controller, also on private network only (the CIDR block of our network e.g. 172.31.0.0/16)
   5. TCP -port 6783 with your CIDR block
   6. UDP -port range 6783-6784 with your CIDR block
2. Make sure the firewall allows the following inbound on the worker nodes as well as all outbound traffic:
   1. SSH — port 22 so that we can ssh from our local machine to all worker nodes
   2. TCP -port 10250 with your CIDR block
   3. TCP -port range 30000–32767 with the source as anywhere IPv4.
   4. TCP -port 6783 with your CIDR block
   5. UDP -port range 6783-6784 with your CIDR block
3. Create a file called `containerd-install.sh` on all machines that are to be included in the cluster and fill it with the commands found in the files of this directory
4. Run `chmod u+x ./containerd-install.sh` and then execute it
5. Create a file called `k8s-install.sh` on all machines that are to be included in the cluster and fill it with the commands found in the files of this directory
6. Run `chmod u+x ./k8s-install.sh` and then execute it
7. From the control plane node, please run `sudo kubeadm init`
8. run the following on the control plane:

    ```shell
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

9. Edit `/etc/containerd/config.toml` file on the control plane as well as on the worker nodes `sudo nano /etc/containerd/config.toml` and change the **SystemCgroup** key from **false** to **true** under **plugins** object
10. Restart **containerd** and **kubelet** services on the control plane and on all nodes:

    ```shell
    sudo service containerd restart
    sudo service kubelet restart
    ```

11. Install the pod network with: `kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml`
12. The `kubeadm init` command should also output a `kubeadm join` command. Use this command to join your worker nodes to your cluster.
    1. You may need to run this command as root using `sudo`!
    2. If you missed the command use `kubeadm token create --print-join-command`
13. Install Helm:

    ```shell
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm
    ```

14. Install ingress:

    ```shell
    helm repo add traefik https://traefik.github.io/charts
    helm repo update
    helm install traefik traefik/traefik
    ```

15. If the External IP is not automatically assigned use: `kubectl patch svc  traefik -p '{"spec":{"externalIPs":["IP_ADDRESS"]}}'`

Additional steps for volume creation:

1. Create a file called `pv.sh` on the control plane and fill it with the commands found in the files of this directory
2. Run `chmod u+x ./pv.sh` and then execute it

Now you are ready to go!
