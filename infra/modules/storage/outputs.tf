output "bucket_name" {
  value = aws_s3_bucket.exports.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.exports.arn
}

output "images_bucket_name" {
  value = aws_s3_bucket.images.bucket
}

output "images_bucket_arn" {
  value = aws_s3_bucket.images.arn
}
