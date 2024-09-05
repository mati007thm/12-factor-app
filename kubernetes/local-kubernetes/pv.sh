# Get all not control-plane nodes
NODE_NAME=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' --no-headers -o name | awk -F'/' '{printf("%s%s", sep, $2); sep=", "} END {print ""}')

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: dapr-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /dev/root
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [$NODE_NAME]
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv-1
spec:
  capacity:
    storage: 8Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /dev/root
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [$NODE_NAME]
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv-2
spec:
  capacity:
    storage: 8Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /dev/root
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [$NODE_NAME]
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv-3
spec:
  capacity:
    storage: 8Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /dev/root
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [$NODE_NAME]
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv-4
spec:
  capacity:
    storage: 8Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /dev/root
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [$NODE_NAME]
EOF
