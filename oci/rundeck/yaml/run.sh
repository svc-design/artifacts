kubectl create secret generic rundeck-adm-policy --from-file=rundeck-admin-role.yaml -n workflow
kubectl apply -f pvc.yaml
kubectl apply -f rundeck-ClusterRole.yaml
kubectl apply -f rundeck-ClusterRoleBinding.yaml
kubectl apply -f rundeck-sa.yaml
kubectl apply -f rundeck.yaml
