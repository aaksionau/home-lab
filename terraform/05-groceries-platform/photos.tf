# PVC for uploaded receipt photos (FileSystemPhotoStore's BasePath), separate
# from the Postgres PVC in postgres.tf -- photos are bulkier and have a
# different growth profile than receipt metadata/line items.
resource "kubernetes_persistent_volume_claim_v1" "receipt_photos" {
  # Same WaitForFirstConsumer reasoning as the postgres PVC in postgres.tf.
  wait_until_bound = false

  metadata {
    name      = "receipt-photos"
    namespace = kubernetes_namespace_v1.groceries.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        # Phone photos, uncompressed by this walking skeleton -- sized with
        # headroom rather than tightly, revisit once real usage shows growth.
        storage = "5Gi"
      }
    }
  }
}
