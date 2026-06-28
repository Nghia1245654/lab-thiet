import json
import os
import sys
from unittest.mock import patch, MagicMock
import pytest

import importlib.util
# Load index module from local directory dynamically to avoid path conflicts
spec = importlib.util.spec_from_file_location("index", os.path.join(os.path.dirname(__file__), "index.py"))
index = importlib.util.module_from_spec(spec)
sys.modules["index"] = index
with patch('boto3.resource'):
    spec.loader.exec_module(index)

@pytest.fixture
def mock_dynamodb():
    with patch('index.dynamodb') as mock:
        yield mock

def test_handler_missing_incident_id():
    event = {}
    response = index.handler(event, None)
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'incident_id is required' in body['error']

def test_handler_success_item_exists(mock_dynamodb):
    # Mock DynamoDB table responses
    mock_table = MagicMock()
    mock_dynamodb.Table.return_value = mock_table
    mock_table.get_item.return_value = {
        'Item': {
            'incident_id': 'inc-12345',
            'status': 'TRIGGERED',
            'correlation_key': 'corr-key-123',
            'alert_fingerprint': 'fp-123'
        }
    }
    
    event = {
        'incident_id': 'inc-12345'
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['jira_ticket_id'] == 'JIRA-INC-1234'
    assert body['slack_thread_id'] == 'SLACK-THREAD-INC-1234'
    assert body['status'] == 'INTEGRATED'
    
    # Assert DynamoDB interaction
    mock_table.get_item.assert_called_once_with(Key={'incident_id': 'inc-12345'})
    mock_table.put_item.assert_not_called()
    mock_table.update_item.assert_called_once()

def test_handler_success_item_does_not_exist(mock_dynamodb):
    mock_table = MagicMock()
    mock_dynamodb.Table.return_value = mock_table
    mock_table.get_item.return_value = {}  # Item not found
    
    event = {
        'incident_id': 'inc-67890',
        'correlation_key': 'corr-key-456',
        'alert_fingerprint': 'fp-456'
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['jira_ticket_id'] == 'JIRA-INC-6789'
    assert body['status'] == 'INTEGRATED'
    
    # Assert DynamoDB interaction
    mock_table.get_item.assert_called_once_with(Key={'incident_id': 'inc-67890'})
    mock_table.put_item.assert_called_once_with(Item={
        'incident_id': 'inc-67890',
        'status': 'TRIGGERED',
        'correlation_key': 'corr-key-456',
        'alert_fingerprint': 'fp-456'
    })
    mock_table.update_item.assert_called_once()

def test_handler_dynamodb_get_item_error(mock_dynamodb):
    mock_table = MagicMock()
    mock_dynamodb.Table.return_value = mock_table
    mock_table.get_item.side_effect = Exception("DynamoDB Read Timeout")
    
    event = {
        'incident_id': 'inc-error-get'
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 200  # Should still proceed and try updating
    
    mock_table.get_item.assert_called_once_with(Key={'incident_id': 'inc-error-get'})
    mock_table.update_item.assert_called_once()

def test_handler_dynamodb_update_item_error(mock_dynamodb):
    mock_table = MagicMock()
    mock_dynamodb.Table.return_value = mock_table
    mock_table.get_item.return_value = {
        'Item': {
            'incident_id': 'inc-error-update',
            'status': 'TRIGGERED'
        }
    }
    mock_table.update_item.side_effect = Exception("DynamoDB Write Timeout")
    
    event = {
        'incident_id': 'inc-error-update'
    }
    
    response = index.handler(event, None)
    assert response['statusCode'] == 200  # Still returns 200 despite failing write
    body = json.loads(response['body'])
    assert body['status'] == 'INTEGRATED'
