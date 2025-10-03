import boto3
import os
import tempfile
from PIL import Image

region_name = os.environ['REGION_NAME']
s3_client = boto3.client('s3', region_name=region_name)

# Set thumbnail size
THUMBNAIL_SIZE = (128, 128)

def lambda_handler(event, context):
    # Get bucket and object info from the S3 event
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        # Skip if it's already a thumbnail
        if key.lower().endswith("_thumbnail.jpg"):
            print(f"Skipping thumbnail: {key}")
            continue

        # Download the file to tmp storage
        with tempfile.TemporaryDirectory() as tmpdir:
            download_path = os.path.join(tmpdir, os.path.basename(key))
            upload_path = os.path.join(tmpdir, f"{os.path.splitext(os.path.basename(key))[0]}_thumbnail.jpg")

            s3_client.download_file(bucket, key, download_path)

            # Open image and create thumbnail
            with Image.open(download_path) as img:
                img.thumbnail(THUMBNAIL_SIZE)
                img.save(upload_path, "JPEG")

            # Upload thumbnail back to S3
            thumbnail_key = f"thumbnails/{os.path.splitext(key)[0]}_thumbnail.jpg"
            s3_client.upload_file(upload_path, bucket, thumbnail_key, ExtraArgs={'ContentType': 'image/jpeg'})

            print(f"Thumbnail saved at: {thumbnail_key}")

