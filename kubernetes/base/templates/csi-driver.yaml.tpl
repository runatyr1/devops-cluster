apiVersion: v1
kind: ServiceAccount
metadata:
  name: hcloud-csi-node
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hcloud-csi-controller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hcloud-csi
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["list", "watch", "create", "update", "patch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["csinodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots"]
  verbs: ["get", "list"]
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshotcontents"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: hcloud-csi
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: hcloud-csi
subjects:
- kind: ServiceAccount
  name: hcloud-csi-controller
  namespace: kube-system
- kind: ServiceAccount
  name: hcloud-csi-node
  namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: hcloud
  namespace: kube-system
stringData:
  token: ${hcloud_token}
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hcloud-volumes
provisioner: csi.hetzner.cloud
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: hdd
---
# From https://raw.githubusercontent.com/hetznercloud/csi-driver/v2.11.0/deploy/kubernetes/hcloud-csi.yml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: hcloud-csi-node
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: hcloud-csi-node
  template:
    metadata:
      labels:
        app: hcloud-csi-node
    spec:
      containers:
      - args:
        - --endpoint=unix:///var/lib/csi/sockets/pluginproxy/csi.sock
        - --node-id=$(NODE_ID)
        - --v=5
        env:
        - name: NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        image: hetznercloud/hcloud-csi-driver:v2.12.0
        imagePullPolicy: IfNotPresent
        name: hcloud-csi-driver
        securityContext:
          privileged: true 
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
        - mountPath: /var/lib/kubelet
          mountPropagation: Bidirectional
          name: kubelet-dir
        - mountPath: /dev
          name: device-dir
      - args:
        - --csi-address=$(ADDRESS)
        - --v=5
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        image: k8s.gcr.io/sig-storage/livenessprobe:v2.10.0
        name: liveness-probe
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
      hostNetwork: true
      serviceAccountName: hcloud-csi-node
      volumes:
      - hostPath:
          path: /var/lib/kubelet
          type: Directory
        name: kubelet-dir
      - hostPath:
          path: /var/lib/csi/sockets/pluginproxy/
          type: DirectoryOrCreate
        name: socket-dir
      - hostPath:
          path: /dev
          type: Directory
        name: device-dir
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hcloud-csi-controller
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hcloud-csi-controller
  template:
    metadata:
      labels:
        app: hcloud-csi-controller
    spec:
      containers:
      - args:
        - --endpoint=unix:///var/lib/csi/sockets/pluginproxy/csi.sock
        - --v=5
        - --leader-election
        image: hetznercloud/hcloud-csi-driver:v2.12.0
        imagePullPolicy: IfNotPresent
        name: hcloud-csi-driver
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
      - args:
        - --csi-address=$(ADDRESS)
        - --v=5
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        image: k8s.gcr.io/sig-storage/csi-provisioner:v3.5.0
        name: csi-provisioner
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
      serviceAccountName: hcloud-csi-controller
      volumes:
      - emptyDir: {}
        name: socket-dir