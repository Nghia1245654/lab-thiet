import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE')
s3_bucket = os.environ.get('S3_BUCKET_NAME')

def handler(event, context):
    print("Received integration event:", json.dumps(event))
    
    incident_id = event.get('incident_id')
    if not incident_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'incident_id is required in request'})
        }
        
    table = dynamodb.Table(table_name)
    
    # 1. Read state from DynamoDB
    try:
        response = table.get_item(Key={'incident_id': incident_id})
        item = response.get('Item')
        if not item:
            print(f"Incident {incident_id} not found in DynamoDB. Creating new stub...")
            item = {
                'incident_id': incident_id,
                'status': 'TRIGGERED',
                'correlation_key': event.get('correlation_key', 'unknown-corr-key'),
                'alert_fingerprint': event.get('alert_fingerprint', 'unknown-fingerprint')
            }
            table.put_item(Item=item)
    except Exception as e:
        print(f"Failed to access DynamoDB: {str(e)}")
        item = {'incident_id': incident_id, 'status': 'DYNAMODB_ERROR'}
        
    # 2. Simulate external Jira Ticket creation
    print(f"Creating Jira ticket for incident {incident_id}...")
    jira_ticket_id = f"JIRA-{incident_id[:8].upper()}"
    
    # 3. Simulate Slack Notification sending
    print(f"Sending Slack alert notification for incident {incident_id}...")
    slack_thread_id = f"SLACK-THREAD-{incident_id[:8].upper()}"
    
    # 4. Update DynamoDB with Jira and Slack info
    try:
        table.update_item(
            Key={'incident_id': incident_id},
            UpdateExpression="set jira_ticket_id = :j, slack_thread_id = :s, #stat = :st",
            ExpressionAttributeNames={'#stat': 'status'},
            ExpressionAttributeValues={
                ':j': jira_ticket_id,
                ':s': slack_thread_id,
                ':st': 'INTEGRATED'
            }
        )
    except Exception as e:
        print(f"Failed to update incident state in DynamoDB: {str(e)}")
        
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'External integrations processed successfully',
            'incident_id': incident_id,
            'jira_ticket_id': jira_ticket_id,
            'slack_thread_id': slack_thread_id,
            'status': 'INTEGRATED'
        })
    }
