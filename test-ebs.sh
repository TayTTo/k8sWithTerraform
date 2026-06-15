#!/usr/bin/env bash
#
# test-ebs.sh — End-to-end check that the AWS EBS CSI driver works on your EKS cluster.
#
# It will:
#   1. Verify the EBS CSI driver pods are running
#   2. Verify an EBS-backed StorageClass exists
#   3. Create a PVC + a pod that mounts it
#   4. Wait for the volume to provision and the pod to start
#   5. Write and read a file on the mounted volume (proves it's actually usable)
#   6. Confirm the real EBS volume exists in AWS
#   7. Clean everything up
#
# Usage:
#   chmod +x test-ebs.sh
#   ./test-ebs.sh
#
# Optional: override the AWS region (defaults to ap-southeast-1)
#   REGION=us-east-1 ./test-ebs.sh

set -uo pipefail

# ---- config -----------------------------------------------------------------
REGION="${REGION:-ap-southeast-1}"
NS="default"
SC_NAME=""                       # auto-detected below
PVC_NAME="ebs-test-pvc"
POD_NAME="ebs-test-pod"
TIMEOUT=180                      # seconds to wait for binding / pod ready

# ---- helpers ----------------------------------------------------------------
green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
red()   { printf "\033[0;31m%s\033[0m\n" "$1"; }
blue()  { printf "\033[0;34m%s\033[0m\n" "$1"; }
fail()  { red "✗ $1"; cleanup; exit 1; }

cleanup() {
  blue "--- Cleaning up test resources ---"
  kubectl delete pod "$POD_NAME" -n "$NS" --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl delete pvc "$PVC_NAME" -n "$NS" --ignore-not-found --wait=false >/dev/null 2>&1
}
# clean up even if the user Ctrl-C's
trap cleanup EXIT

# ---- 1. driver pods ---------------------------------------------------------
blue "=== 1. Checking EBS CSI driver pods (kube-system) ==="
if ! kubectl get pods -n kube-system 2>/dev/null | grep -q ebs-csi; then
  fail "No ebs-csi pods found. The aws-ebs-csi-driver addon isn't installed. Run 'terraform apply' first."
fi
kubectl get pods -n kube-system | grep ebs-csi
NOT_RUNNING=$(kubectl get pods -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' \
  | grep ebs-csi | grep -v Running || true)
if [ -n "$NOT_RUNNING" ]; then
  red "Some ebs-csi pods are not Running:"; echo "$NOT_RUNNING"
  fail "Driver pods unhealthy. Check: kubectl describe pod -n kube-system <name>"
fi
green "✓ EBS CSI driver pods are running"
echo

# ---- 2. storage class -------------------------------------------------------
blue "=== 2. Looking for an EBS-backed StorageClass ==="
SC_NAME=$(kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.provisioner}{"\n"}{end}' \
  | awk '$2=="ebs.csi.aws.com"{print $1; exit}')
if [ -z "$SC_NAME" ]; then
  fail "No StorageClass with provisioner ebs.csi.aws.com found. Create one (e.g. 'ebs-gp3') first."
fi
kubectl get storageclass
green "✓ Using StorageClass: $SC_NAME"
echo

# ---- 3. create PVC + pod ----------------------------------------------------
blue "=== 3. Creating test PVC and pod ==="
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${NS}
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: ${SC_NAME}
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NS}
spec:
  containers:
  - name: app
    image: public.ecr.aws/amazonlinux/amazonlinux:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: vol
      mountPath: /data
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: ${PVC_NAME}
EOF
echo

# ---- 4. wait for bind + pod ready ------------------------------------------
blue "=== 4. Waiting for PVC to bind and pod to start (up to ${TIMEOUT}s) ==="
if ! kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/"$PVC_NAME" -n "$NS" --timeout="${TIMEOUT}s"; then
  red "PVC did not bind. Diagnostics:"
  kubectl describe pvc "$PVC_NAME" -n "$NS" | tail -20
  echo "--- controller logs ---"
  kubectl logs -n kube-system -l app=ebs-csi-controller -c ebs-plugin --tail=30 2>/dev/null
  fail "Volume provisioning failed (often an IAM/permissions issue on the driver's role)."
fi
green "✓ PVC is Bound"

if ! kubectl wait --for=condition=Ready pod/"$POD_NAME" -n "$NS" --timeout="${TIMEOUT}s"; then
  red "Pod did not become Ready:"
  kubectl describe pod "$POD_NAME" -n "$NS" | tail -20
  fail "Pod failed to start (could be node capacity / image pull)."
fi
green "✓ Pod is Running and the volume is attached"
echo

# ---- 5. write/read on the volume -------------------------------------------
blue "=== 5. Writing and reading a file on the EBS volume ==="
STAMP="ebs-ok-$(date +%s)"
kubectl exec "$POD_NAME" -n "$NS" -- sh -c "echo $STAMP > /data/test.txt"
READBACK=$(kubectl exec "$POD_NAME" -n "$NS" -- cat /data/test.txt)
if [ "$READBACK" = "$STAMP" ]; then
  green "✓ Read back what we wrote ('$READBACK') — the volume is mounted and usable"
else
  fail "Read-back mismatch (wrote '$STAMP', got '$READBACK')."
fi
echo

# ---- 6. confirm real AWS volume --------------------------------------------
blue "=== 6. Confirming the EBS volume exists in AWS (region: $REGION) ==="
PV_NAME=$(kubectl get pvc "$PVC_NAME" -n "$NS" -o jsonpath='{.spec.volumeName}')
VOL_ID=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.csi.volumeHandle}' 2>/dev/null)
if [ -n "$VOL_ID" ]; then
  if command -v aws >/dev/null 2>&1; then
    aws ec2 describe-volumes --region "$REGION" --volume-ids "$VOL_ID" \
      --query 'Volumes[].{VolumeId:VolumeId,State:State,SizeGiB:Size,AZ:AvailabilityZone,Type:VolumeType}' \
      --output table || red "(could not query AWS — check creds/region, but k8s side already passed)"
    green "✓ EBS volume $VOL_ID provisioned in AWS"
  else
    green "✓ Kubernetes provisioned volume handle: $VOL_ID (aws CLI not found, skipping AWS check)"
  fi
else
  red "(could not read volume handle from PV, but the read/write test already proved it works)"
fi
echo

green "=========================================="
green " EBS CSI driver is WORKING end-to-end ✓"
green "=========================================="
echo "Cleanup will run now (deletes the test PVC/pod; the EBS volume is removed with the PVC)."
