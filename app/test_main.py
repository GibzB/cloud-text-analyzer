import pytest
import json
from main import app


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_analyze_endpoint(client):
    response = client.post('/analyze',
                           data=json.dumps({'text': 'Hello world'}),
                           content_type='application/json')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['original_text'] == 'Hello world'
    assert data['word_count'] == 2
    assert data['character_count'] == 11


def test_health_endpoint(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'ok'


def test_missing_text_field(client):
    response = client.post('/analyze',
                           data=json.dumps({}),
                           content_type='application/json')
    assert response.status_code == 400
