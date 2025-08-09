from flask import Flask, request, jsonify
import os

app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <h2>Text Analyzer API</h2>
    <p>POST /analyze - Analyze text</p>
    <p>GET /health - Health check</p>
    
    <form action="/analyze" method="post" style="margin-top:20px;">
        <label>Text to analyze:</label><br>
        <textarea name="text" rows="4" cols="50" placeholder="Enter your text here"></textarea><br><br>
        <button type="submit">Analyze</button>
    </form>
    '''

@app.route('/analyze', methods=['POST'])
def analyze_text():
    # Get text from request
    if request.is_json:
        data = request.get_json()
        text = data.get('text', '')
    else:
        text = request.form.get('text', '')
        
    if not text:
        return jsonify({'error': 'Text field is required'}), 400
    
    # Simple analysis
    words = text.split()
    word_count = len(words)
    char_count = len(text)
    
    result = {
        'original_text': text,
        'word_count': word_count,
        'character_count': char_count
    }
    
    return jsonify(result)

@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)