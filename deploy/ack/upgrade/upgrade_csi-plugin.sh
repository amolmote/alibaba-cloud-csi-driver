#!/bin/bash

## Usage
## Append image tag which is expect.
## bash upgrade_csi-plugin.sh v1.18.8.47-906bd535-aliyun


if [ "$1" = "" ]; then
  echo "Please input the expect csi plugin version... "
fi
imageVersion=$1

echo `date`" Start to Upgrade CSI Plugin to $imageVersion ..."

# new deploy template file
# if any changes, just update here and replace image value
cat > .aliyun-csi-plugin-addition.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: csi-admin
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: alicloud-csi-plugin
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "create"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "update", "create", "delete", "patch"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims/status"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["csinodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "watch", "list", "delete", "update", "create"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "watch", "list", "delete", "update", "create"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["csi.storage.k8s.io"]
    resources: ["csinodeinfos"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["volumeattachments"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotclasses"]
    verbs: ["get", "list", "watch", "create"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotcontents"]
    verbs: ["create", "get", "list", "watch", "update", "delete"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshots"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["create", "list", "watch", "delete", "get", "update", "patch"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "create", "list", "watch", "delete", "update"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotcontents/status"]
    verbs: ["update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["volumeattachments/status"]
    verbs: ["patch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshots/status"]
    verbs: ["update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: alicloud-csi-plugin
subjects:
  - kind: ServiceAccount
    name: csi-admin
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: alicloud-csi-plugin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: diskplugin.csi.alibabacloud.com
spec:
  attachRequired: true
  podInfoOnMount: true
---
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: nasplugin.csi.alibabacloud.com
spec:
  attachRequired: false
  podInfoOnMount: true
---
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: ossplugin.csi.alibabacloud.com
spec:
  attachRequired: false
  podInfoOnMount: true
EOF

cat > .aliyun-csi-plugin.yaml << EOF
---
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: csi-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: csi-plugin
  template:
    metadata:
      labels:
        app: csi-plugin
    spec:
      tolerations:
        - operator: Exists
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: type
                operator: NotIn
                values:
                - virtual-kubelet
      nodeSelector:
        beta.kubernetes.io/os: linux
      serviceAccount: admin
      priorityClassName: system-node-critical
      hostNetwork: true
      hostPID: true
      containers:
        - name: disk-driver-registrar
          image: csi-image-prefix/acs/csi-node-driver-registrar:v1.2.0
          imagePullPolicy: Always
          args:
            - "--v=5"
            - "--csi-address=/var/lib/kubelet/csi-plugins/diskplugin.csi.alibabacloud.com/csi.sock"
            - "--kubelet-registration-path=/var/lib/kubelet/csi-plugins/diskplugin.csi.alibabacloud.com/csi.sock"
          volumeMounts:
            - name: kubelet-dir
              mountPath: /var/lib/kubelet
            - name: registration-dir
              mountPath: /registration
        - name: nas-driver-registrar
          image: csi-image-prefix/acs/csi-node-driver-registrar:v1.2.0
          imagePullPolicy: Always
          args:
            - "--v=5"
            - "--csi-address=/var/lib/kubelet/csi-plugins/nasplugin.csi.alibabacloud.com/csi.sock"
            - "--kubelet-registration-path=/var/lib/kubelet/csi-plugins/nasplugin.csi.alibabacloud.com/csi.sock"
          volumeMounts:
            - name: kubelet-dir
              mountPath: /var/lib/kubelet/
            - name: registration-dir
              mountPath: /registration
        - name: oss-driver-registrar
          image: csi-image-prefix/acs/csi-node-driver-registrar:v1.2.0
          imagePullPolicy: Always
          args:
            - "--v=5"
            - "--csi-address=/var/lib/kubelet/csi-plugins/ossplugin.csi.alibabacloud.com/csi.sock"
            - "--kubelet-registration-path=/var/lib/kubelet/csi-plugins/ossplugin.csi.alibabacloud.com/csi.sock"
          volumeMounts:
            - name: kubelet-dir
              mountPath: /var/lib/kubelet/
            - name: registration-dir
              mountPath: /registration
        - name: csi-plugin
          securityContext:
            privileged: true
            capabilities:
              add: ["SYS_ADMIN"]
            allowPrivilegeEscalation: true
          image: csi-image-prefix/acs/csi-plugin:csi-image-version
          imagePullPolicy: "Always"
          args:
            - "--endpoint=\$(CSI_ENDPOINT)"
            - "--v=2"
            - "--driver=oss,nas,disk"
          env:
            - name: KUBE_NODE_NAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: spec.nodeName
            - name: CSI_ENDPOINT
              value: unix://var/lib/kubelet/csi-plugins/driverplugin.csi.alibabacloud.com-replace/csi.sock
            - name: MAX_VOLUMES_PERNODE
              value: "15"
            - name: SERVICE_TYPE
              value: "plugin"
          livenessProbe:
            httpGet:
              path: /healthz
              port: healthz
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 5
          ports:
            - name: healthz
              containerPort: 11260
              protocol: TCP
          volumeMounts:
            - name: kubelet-dir
              mountPath: /var/lib/kubelet/
              mountPropagation: "Bidirectional"
            - name: etc
              mountPath: /host/etc
            - name: host-log
              mountPath: /var/log/
            - name: ossconnectordir
              mountPath: /host/usr/
            - name: container-dir
              mountPath: /var/lib/container
              mountPropagation: "Bidirectional"
            - name: host-dev
              mountPath: /dev
              mountPropagation: "HostToContainer"
            - mountPath: /var/addon
              name: addon-token
              readOnly: true
      volumes:
        - name: registration-dir
          hostPath:
            path: /var/lib/kubelet/plugins_registry
            type: DirectoryOrCreate
        - name: container-dir
          hostPath:
            path: /var/lib/container
            type: DirectoryOrCreate
        - name: kubelet-dir
          hostPath:
            path: /var/lib/kubelet
            type: Directory
        - name: host-dev
          hostPath:
            path: /dev
        - name: host-log
          hostPath:
            path: /var/log/
        - name: etc
          hostPath:
            path: /etc
        - name: ossconnectordir
          hostPath:
            path: /usr/
        - name: addon-token
          secret:
            defaultMode: 420
            optional: true
            items:
            - key: addon.token.config
              path: token-config
            secretName: addon.csi.token
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 10%
    type: RollingUpdate
EOF

# get registry address
imageBefore=`kubectl describe ds csi-plugin -nkube-system | grep Image: | grep acs/csi-plugin | awk 'NR==1 {print $2}'`
imagePrefix=`kubectl describe ds csi-plugin -nkube-system | grep Image: | grep acs/csi-plugin | awk 'NR==1 {print $2}' | awk -F: '{print $1}' | awk -F/ '{print $1}'`
imageName=${imagePrefix}/acs/csi-plugin:$imageVersion

## Check current version
if [[ $imagePrefix != registry* ]] || [[ $imagePrefix != *aliyuncs.com ]]; then
    echo "Setting image is not expect: "$imagePrefix
    exit 0
fi

if [[ $imageVersion != *aliyun ]]; then
    echo "current image version is not expect: "$imageVersion
    exit 0
fi


diskdriver=`kubectl get csidriver | grep diskplugin.csi.alibabacloud.com | awk '{print $2}'`
nasdriver=`kubectl get csidriver | grep nasplugin.csi.alibabacloud.com | awk '{print $3}'`
ossdriver=`kubectl get csidriver | grep ossplugin.csi.alibabacloud.com | awk '{print $3}'`

if [ "$diskdriver" = "false" ]; then
    kubectl delete csidriver diskplugin.csi.alibabacloud.com
fi

if [ "$nasdriver" = "false" ]; then
    kubectl delete csidriver nasplugin.csi.alibabacloud.com
fi

if [ "$ossdriver" = "false" ]; then
    kubectl delete csidriver ossplugin.csi.alibabacloud.com
fi


echo "Apply plugin additions..."
kubectl apply -f .aliyun-csi-plugin-addition.yaml

## do csi-plugin upgrade
canApply=`kubectl get ds csi-plugin -nkube-system -oyaml |grep kubectl.kubernetes.io/last-applied-configuration | wc -l`
if [ "$canApply" != "0" ]; then
  echo "Upgrade CSI plugin with kubectl apply..."
  cat .aliyun-csi-plugin.yaml | sed "s/csi-image-prefix/$imagePrefix/" | sed "s/csi-image-version/$imageVersion/" | kubectl apply -f -
else
  echo "Upgrade CSI plugin with kubectl replace..."
  cat .aliyun-csi-plugin.yaml | sed "s/csi-image-prefix/$imagePrefix/" | sed "s/csi-image-version/$imageVersion/" | kubectl replace -f -
fi


echo "Upgrade csi plugin from $imageBefore to $imageName"
