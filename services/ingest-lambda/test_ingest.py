import json
import os
import sys
from unittest.mock import patch, MagicMock
import pytest

import importlib.util
# Load index module from local directory dynamically to avoid path conflicts
spec = importlib.util.spec_from_file_location("ingest_lambda_index", os.path.join(os.path.dirname(__file__), "index.py"))
index = importlib.util.module_from_spec(spec)
sys.modules["ingest_lambda_index"] = index
with patch('boto3.client'):
    spec.loader.exec_module(index)

@pytest.fixture
def mock_sqs():
    with patch('ingest_lambda_index.sqs') as mock:
        yield mock

def test_handler_success(mock_sqs):
    # Setup mock SQS response
    mock_sqs.send_message.return_value = {'MessageId': '12345'}
    
    # Setup test event
    event = {
        'body': json.dumps({
            'alerts': [
                {
                    'status': 'firing',
                    'labels': {
                        'tenant_id': 'tenant1',
                        'service': 'frontend',
                        'alertname': 'HighLatency'
                    },
                    'annotations': {
                        'summary': 'Frontend latency is high'
                    }
                }
            ]
        })
    }
    
    response = index.handler(event, None)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['message'] == 'Successfully processed alerts'
    assert body['success_count'] == 1
    
    mock_sqs.send_message.assert_called_once()
    args, kwargs = mock_sqs.send_message.call_args
    assert kwargs['MessageGroupId'] == 'tenant1-frontend'

def test_handler_single_alert_fallback(mock_sqs):
    mock_sqs.send_message.return_value = {'MessageId': '12345'}
    
    event = {
        'body': json.dumps({
            'status': 'firing',
            'labels': {
                'tenant_id': 'tenant2',
                'service': 'backend'
            }
        })
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['success_count'] == 1

def test_handler_invalid_json():
    event = {
        'body': '{invalid-json'
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body

def test_handler_no_alert_data():
    event = {
        'body': json.dumps({'something_else': 'here'})
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'No alert data found in payload' in body['error']

def test_handler_base64_encoded(mock_sqs):
    mock_sqs.send_message.return_value = {'MessageId': '12345'}
    import base64
    
    payload = {
        'alerts': [{
            'status': 'firing',
            'labels': {'tenant_id': 't3', 'service': 'db'}
        }]
    }
    encoded_body = base64.b64encode(json.dumps(payload).encode('utf-8')).decode('utf-8')
    
    event = {
        'isBase64Encoded': True,
        'body': encoded_body
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['success_count'] == 1

def test_handler_sqs_error(mock_sqs):
    mock_sqs.send_message.side_effect = Exception("SQS network error")
    
    event = {
        'body': json.dumps({
            'alerts': [{
                'status': 'firing',
                'labels': {'tenant_id': 't4', 'service': 'cache'}
            }]
        })
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 500
    body = json.loads(response['body'])
    assert 'Failed to push some alerts to SQS' in body['message']
    assert len(body['errors']) == 1
    assert body['errors'][0] == "SQS network error"
