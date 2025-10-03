# Serverless Image Processing Architecture

## Overview

This project is a practice of a building serverless infrastructure for a websites that lets users upload images.
then a lambda function respond to an upload event and creates a thumbnail image for the uploaded image.

## Architecture

![Architecture](https://github.com/waleedkhamees/serverless-image-processing-architecture/blob/master/assets/architecture.png)

## Services used

- 2x AWS Lambda Functions
    - One for creating a thumbnail image
    - One for creating a presigned url for image upload
- API Gateway
    - API gateway is used to make the application
    - Home page (/): has a form where the user can upload an image
    - Upload route: is a route that is triggered when the user uploads an image which creates a presigned url for the image
    and then uploads the image to S3 bucket
- 2x S3 Buckets
    - One to host the website (Public Bucket)
    - One to store the images (Private Bucket)
- IAM
    - For roles to the lambda functions and API gateway

