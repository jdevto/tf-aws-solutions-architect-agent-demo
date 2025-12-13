# =============================================================================
# RANDOM SUFFIX FOR BUCKET NAME
# =============================================================================

resource "random_id" "bucket_suffix" {
  byte_length = 2 # 2 bytes = 4 hex characters
}

# =============================================================================
# S3 BUCKET
# =============================================================================

resource "aws_s3_bucket" "this" {
  bucket = "${var.prefix}-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.prefix}-${random_id.bucket_suffix.hex}"
  })
}

# =============================================================================
# S3 BUCKET VERSIONING
# =============================================================================

resource "aws_s3_bucket_versioning" "this" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# =============================================================================
# S3 BUCKET PUBLIC ACCESS BLOCK
# =============================================================================

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# S3 BUCKET FILE UPLOADS
# =============================================================================

resource "aws_s3_object" "files" {
  for_each = var.upload_files != null ? fileset(var.upload_files.source_dir, var.upload_files.file_pattern) : toset([])

  bucket = aws_s3_bucket.this.id
  key    = var.upload_files != null && var.upload_files.s3_prefix != null ? "${var.upload_files.s3_prefix}/${each.value}" : each.value
  source = var.upload_files != null ? "${var.upload_files.source_dir}/${each.value}" : null
  content_type = var.upload_files != null ? lookup(
    var.upload_files.content_types,
    regex("\\.[^.]+$", each.value),
    "application/octet-stream"
  ) : "application/octet-stream"
  etag = var.upload_files != null ? filemd5("${var.upload_files.source_dir}/${each.value}") : null

  tags = merge(var.tags, {
    Name = each.value
  })

  depends_on = [aws_s3_bucket.this]
}
