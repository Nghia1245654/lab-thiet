import json
import os
import boto3

sqs = boto3.client('sqs')
queue_url = os.environ.get('SQS_QUEUE_URL')

def handler(event, context):
    print("Received event:", json.dumps(event))
    
    # Extract body from Function URL request
    body_str = event.get('body', '{}')
    if event.get('isBase64Encoded', False):
        import base64
        body_str = base64.b64decode(body_str).decode('utf-8')
        
    try:
        payload = json.loads(body_str)
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON payload', 'details': str(e)})
        }
        
    # Validate required fields
    alerts = payload.get('alerts', [])
    if not alerts:
        # If it's a single alert instead of Prometheus list format, wrap it
        if 'status' in payload or 'labels' in payload:
            alerts = [payload]
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No alert data found in payload'})
            }
            
    success_count = 0
    errors = []
    
    for alert in alerts:
        # Normalize / standard format
        labels = alert.get('labels', {})
        annotations = alert.get('annotations', {})
        
        normalized_alert = {
            'status': alert.get('status', 'firing'),
            'labels': labels,
            'annotations': annotations,
            'startsAt': alert.get('startsAt', ''),
            'generatorURL': alert.get('generatorURL', '')
        }
        
        # Deduplication and Grouping keys
        tenant_id = labels.get('tenant_id', 'default-tenant')
        service = labels.get('service', 'unknown-service')
        
        # FIFO requirements: MessageGroupId is required
        # Group by tenant_id + service to ensure ordered processing per service
        message_group_id = f"{tenant_id}-{service}"
        
        try:
            response = sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(normalized_alert),
                MessageGroupId=message_group_id
            )
            success_count += 1
        except Exception as e:
            errors.append(str(e))
            
    if errors:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Failed to push some alerts to SQS',
                'success_count': success_count,
                'errors': errors
            })
        }
        
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Successfully processed alerts',
            'success_count': success_count
        })
    }
