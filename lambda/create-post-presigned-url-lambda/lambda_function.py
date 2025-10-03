import json
import boto3
import os


def create_post_presigned_url(bucket_name, object_name, region_name, expiration=3600):
    s3_client = boto3.client('s3', region_name=region_name)
    response = s3_client.generate_presigned_post(bucket_name, object_name, ExpiresIn=expiration)
    print(response)
    return response

def lambda_handler(event, context):
    print (event)
    body = json.loads(event['body'])
    file_name, file_type = body['file_name'], body['file_type']
    if file_type not in ['image/jpeg', 'image/png', "image/jpg"]:
        return {
            'statusCode': 400,
            'body': json.dumps('File type not supported')
        }
    bucket_name = os.environ['BUCKET_NAME']
    region_name = os.environ['REGION_NAME']
    path = f'originals/{file_name}'

    try:
        presigned_response = create_post_presigned_url(bucket_name, path, region_name)
        return {
            'statusCode': 200,
            'body': json.dumps(presigned_response)
        }
    except:
        return {
            'statusCode': 500,
            'body': json.dumps({"error": "Internal Server Error"})
        }

