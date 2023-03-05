from flask import Flask, request, jsonify
from flask_cors import CORS, cross_origin
import sqlite3
import openai
import time
from loguru import logger
app = Flask(__name__)
openai.api_key = "你的api_key"
DB_NAME = 'chat_history.db'
CORS(app, supports_credentials=True)

def create_table():
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS chat_history
                 (username text, message text, answer text, prompt_cause integer, answer_cause integer, total_cause, response text, status text, create_time integer)''')
    conn.commit()
    conn.close()

create_table()

@app.route('/users', methods=['GET'])
def users():
    logger.info("get users")
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("SELECT distinct username FROM chat_history")
    results = c.fetchall()
    conn.close()
    return jsonify({"users": [{'username':result[0]} for result in results]})

@app.route('/chat', methods=['POST'])
@cross_origin(supports_credentials=True)
def chat():
    json = request.get_json()
    username = json['username']
    message = json['message']
    remember = json['remember']
    logger.info("chat, username: {}, message: {}, remember:{}", username, message, remember)
    # 加载历史对话
    messages = []

    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    if remember == '1':
        c.execute("SELECT * FROM chat_history WHERE status = ? and username = ? ORDER BY create_time DESC LIMIT 10", ("1", username))
        results = c.fetchall()
        # 构造对话,搭建场景
        # 预置姓名
        for result in results:
            messages.append({"role": "user", "content": result[1]})
            messages.append({"role": "assistant", "content": result[2]})
    # 加入本次对话
    messages.append({"role": "user", "content": message})
    try:
        completion = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=messages,
            timeout = 30
        )
        response = completion["choices"][0]['message']['content']

        prompt_cause = int(completion['usage']['prompt_tokens'])
        answer_cause = int(completion['usage']['completion_tokens'])
        total_cause = int(completion['usage']['total_tokens'])
        status = "1"
    except BaseException as e:
        logger.exception(e)
        response = "请求超时！"
        completion = str(e)
        status = "0"
        prompt_cause = 0
        answer_cause = 0
        total_cause = 0

    c.execute("INSERT INTO chat_history VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", (username, message, response,prompt_cause, answer_cause, total_cause, str(completion), status, time.time()))
    conn.commit()
    conn.close()
    return jsonify({"username":"assistant","response": response})

@app.route('/chat_history', methods=['GET'])
def chat_history():
    logger.info("get chat history")
    username = request.args.get('username')
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("SELECT * FROM chat_history WHERE username=? order by create_time asc", (username,))
    results = c.fetchall()
    conn.close()
    chat_history = []
    for result in results:
        chat_history.append({'username': result[0], 'message': result[1]})
        chat_history.append({'username': 'assistant', 'message': result[2]})
    return jsonify({"chat_history": chat_history})

if __name__ == '__main__':
    app.run(port=5000, debug=True)
