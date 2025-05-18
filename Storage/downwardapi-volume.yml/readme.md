# Kubernetes Downward API Pod Example

This pod demonstrates how to use the **Kubernetes Downward API** to expose Pod metadata (labels and annotations) to a container via a volume.

---

## 🔍 What This Pod Does

- Uses a **Downward API volume** to mount pod metadata into the container:
  - `metadata.labels` → `/etc/podinfo/labels`
  - `metadata.annotations` → `/etc/podinfo/annotations`
- A BusyBox container runs a loop to:
  - Read the metadata files
  - Print their contents to standard output every 5 seconds

---

## 📁 Mounted Files in Container

| File Path                  | Content Source             |
|---------------------------|----------------------------|
| `/etc/podinfo/labels`     | `metadata.labels`          |
| `/etc/podinfo/annotations`| `metadata.annotations`     |

---

## 🚀 How to Use

1. **Apply the Pod YAML:**

   ```bash
   kubectl apply -f downwardapi-volume-pod.yml
   ```

2. **Check the Pod status:**

   ```bash
   kubectl get pods
   ```

3. **View the logs to see metadata:**

   ```bash
   kubectl logs kubernetes-downwardapi-volume-example
   ```

   You should see:

   ```ini
   zone="us-est-coast"
   cluster="test-cluster1"
   rack="rack-22"
   build="two"
   builder="john-doe"
   ```

---

## 🏗️ How This Is Useful in Production

| Use Case                    | Description                                                                 |
|-----------------------------|-----------------------------------------------------------------------------|
| Logging metadata            | Attach labels to logs for observability tools like ELK, Loki, etc.          |
| Custom config injection     | Inject cluster, rack, or zone data into config files dynamically.           |
| Metadata-aware sidecars     | Allow sidecar containers to react based on labels or annotations.           |

---

## 🧪 Optional Extensions

To add more metadata (like Pod name or namespace), edit your YAML to include:

```yaml
- path: "podname"
  fieldRef:
    fieldPath: metadata.name
- path: "namespace"
  fieldRef:
    fieldPath: metadata.namespace
```

These will appear as additional files under `/etc/podinfo/`.

---

## 📌 Notes

- This method provides read-only access to metadata.
- Useful for decoupling configuration logic from application code.
- Requires no changes to the application itself.
