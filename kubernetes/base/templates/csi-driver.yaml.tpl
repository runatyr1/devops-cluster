apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: csi.hetzner.cloud
spec:
  attachRequired: true
  fsGroupPolicy: File
  podInfoOnMount: true
  seLinuxMount: true
  volumeLifecycleModes:
  - Persistent
---
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
  verbs: ["get", "list", "watch", "create", "delete", "patch"] 
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update", "patch"] 
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch", "update", "patch"] 
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["list", "watch", "create", "update", "patch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["csinodes"]
  verbs: ["get", "list", "watch", "update"]  
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots"]
  verbs: ["get", "list", "watch"] 
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshotcontents"]
  verbs: ["get", "list", "watch"] 
- apiGroups: ["storage.k8s.io"]
  resources: ["volumeattachments"]
  verbs: ["get", "list", "watch", "create", "delete", "patch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["csidrivers"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["volumeattachments/status"]
  verbs: ["patch"]
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
      serviceAccountName: hcloud-csi-node
      hostNetwork: true
      containers:
      - name: csi-node-driver-registrar
        image: registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.13.0
        args:
          - --kubelet-registration-path=/var/lib/kubelet/plugins/csi.hetzner.cloud/socket
        volumeMounts:
          - name: plugin-dir
            mountPath: /run/csi
          - name: registration-dir
            mountPath: /registration

      - name: hcloud-csi-driver
        image: hetznercloud/hcloud-csi-driver:v2.12.0
        command: ["/bin/hcloud-csi-driver-node"]
        args:
          - --node-id=$(NODE_ID)
          - --v=5
        env:
          - name: CSI_ENDPOINT
            value: unix:///run/csi/socket
          - name: ENABLE_METRICS
            value: "true"
          - name: NODE_ID
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
        securityContext:
          privileged: true
        volumeMounts:
          - name: kubelet-dir
            mountPath: /var/lib/kubelet
            mountPropagation: Bidirectional
          - name: plugin-dir
            mountPath: /run/csi
          - name: device-dir
            mountPath: /dev

      - name: liveness-probe
        image: registry.k8s.io/sig-storage/livenessprobe:v2.15.0
        args:
          - --csi-address=/run/csi/socket
        volumeMounts:
          - name: plugin-dir
            mountPath: /run/csi

      volumes:
        - name: kubelet-dir
          hostPath:
            path: /var/lib/kubelet
            type: Directory
        - name: plugin-dir
          hostPath:
            path: /var/lib/kubelet/plugins/csi.hetzner.cloud/
            type: DirectoryOrCreate
        - name: registration-dir
          hostPath:
            path: /var/lib/kubelet/plugins_registry/
            type: Directory
        - name: device-dir
          hostPath:
            path: /dev
            type: Directory
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
      serviceAccountName: hcloud-csi-controller
      containers:
      - name: csi-attacher
        image: registry.k8s.io/sig-storage/csi-attacher:v4.8.0
        args:
          - --default-fstype=ext4
          - --csi-address=/run/csi/socket
        volumeMounts:
          - name: socket-dir
            mountPath: /run/csi

      - name: csi-resizer
        image: registry.k8s.io/sig-storage/csi-resizer:v1.12.0
        args:
          - --csi-address=/run/csi/socket
        volumeMounts:
          - name: socket-dir
            mountPath: /run/csi

      - name: csi-provisioner
        image: registry.k8s.io/sig-storage/csi-provisioner:v3.5.0
        args:
          - --csi-address=/run/csi/socket
          - --feature-gates=Topology=true
          - --default-fstype=ext4
        volumeMounts:
          - name: socket-dir
            mountPath: /run/csi

      - name: hcloud-csi-driver
        image: hetznercloud/hcloud-csi-driver:v2.12.0
        command: ["/bin/hcloud-csi-driver-controller"]
        args:
          - --v=5
          - --leader-election
        env:
          - name: CSI_ENDPOINT
            value: unix:///run/csi/socket
          - name: ENABLE_METRICS
            value: "true"
          - name: HCLOUD_TOKEN
            valueFrom:
              secretKeyRef:
                name: hcloud
                key: token
        volumeMounts:
          - name: socket-dir
            mountPath: /run/csi

      - name: liveness-probe
        image: registry.k8s.io/sig-storage/livenessprobe:v2.15.0
        args:
          - --csi-address=/run/csi/socket
        volumeMounts:
          - name: socket-dir
            mountPath: /run/csi

      volumes:
        - name: socket-dir
          emptyDir: {}