import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

String _serverUrl = "http://xxx.xxx.xxx/chat_api";

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '神奇海螺试验场',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: '神奇海螺试验场'),
    );
  }
}
class Chat {
  final String username; // 用户名
  final String message; // 消息

  Chat({required this.username, required this.message});

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      username: json['username'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'message': message,
      };
}

class User {
  final String username;

  User({required this.username});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(username: json['username']);
  }

  Map<String, dynamic> toJson() => {
        'username': username,
      };
}

/**
 * 主页
 * 
 */
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  //标题
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late List<Chat> _chats = [];
  late User _selectedUser = User(username: '海绵宝宝');
  late List<User> _users = [_selectedUser];
  late bool remember = false;
  late bool isSending = false;

  TextEditingController _textEditingController = TextEditingController();
  ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final response = await http.get(Uri.parse(
        '$_serverUrl/chat_history?username=${_selectedUser.username}'));

    if (response.statusCode == 200) {
      setState(() {
        _chats = json
            .decode(response.body)['chat_history']
            .map<Chat>((chat) => Chat.fromJson(chat))
            .toList();
      });
    }
  }

  Future<void> _sendMessage(String message) async {
    //如果消息为空，什么都不做
    if (message.isEmpty) return;
    setState(() {
      //添加到聊天框
      _chats.add(Chat(username: _selectedUser.username, message: message));
      //清理
      _textEditingController.clear();
      // 显示等待动画
      isSending = true;
    });
    _scrollToBottom();

    final response = await http.post(Uri.parse('$_serverUrl/chat'),
        body: json.encode({
          'username': _selectedUser.username,
          'message': message,
          'remember': remember ? '1' : '0'
        }),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        });
    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);
      setState(() {
        _chats.add(
            Chat(username: result['username'], message: result['response']));
        _textEditingController.clear();
        isSending = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _scrollToBottom() async {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _listScrollController.animateTo(
        _listScrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /**
   * 加载用户列表
   */

  Future<void> _loadUsers() async {
    final response = await http.get(Uri.parse('$_serverUrl/users'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['users'];
      //判断是否为空
      if (jsonResponse.isNotEmpty) {
        setState(() {
          // 初始化用户列表
          _users = jsonResponse.map((user) => User.fromJson(user)).toList();
          _selectedUser = _users[0];
          _loadChatHistory();
        });
      } else {
        setState(() {
          _selectedUser = User(username: '海绵宝宝');
          _users = [_selectedUser];
          _loadChatHistory();
        });
      }
    } else {
      throw Exception('Failed to load users');
    }
  }

  /**
  * 变更用户
  */
  Future<void> _switchUser(String userName) async {
    setState(() {
      _selectedUser = _users.firstWhere((user) => user.username == userName);
      // 清空聊天记录
      _chats = [];
    });
    await _loadChatHistory();
  }

/**
 * 添加用户
 */
  Future<void> _addUser(String userName) async {
    setState(() {
      _users.add(new User(username: userName));
      _switchUser(userName);
    });
  }

/**
 * 变更记忆
 */
  Future<void> _changeRemember(bool? value) async {
    setState(() {
      remember = value!;
    });
  }

  Future<void> _inputChange(value) async {
    // 如果正在发送，不做任何处理
    if (isSending) return;

    // 发送
    // 按下了 shift+Enter
    if (RawKeyboard.instance.keysPressed
        .contains(LogicalKeyboardKey.shiftLeft)) {
      // 结尾为\n时不发送，换行
      setState(() {
        // 如果按下了 Shift+Enter，则在输入框内添加一个换行符
        _textEditingController.value = TextEditingValue(
          text: value + '\n',
          selection: TextSelection.collapsed(
            offset: value.length,
          ),
        );
      });
      return;
    }

    // 按下了 Enter
    _sendMessage(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("你为什么不问问神奇海螺呢？"),
      ),
      drawer: Drawer(
        child: ListView.builder(
          itemCount: _users.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: GestureDetector(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "添加一个新用户！",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        "点击这里添加新用户",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        String name = "";
                        return AlertDialog(
                          title: Text("你的名字叫什么呢？"),
                          content: TextField(
                            decoration: InputDecoration(
                              hintText: "痞老板？",
                            ),
                            onChanged: (value) {
                              name = value;
                            },
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: Text("取消"),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                            TextButton(
                              child: Text("添加"),
                              onPressed: () {
                                _addUser(name);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            }
            return ListTile(
              title: Text(_users[index - 1].username),
              onTap: () {
                setState(() {
                  _selectedUser = _users[index - 1];
                  _loadChatHistory();
                });
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            //消息框
            Expanded(
              child: ListView.builder(
                controller: _listScrollController,
                itemCount: _chats.length,
                itemBuilder: (BuildContext context, int index) {
                  final message = _chats[index];
                  final bool isMe = message.username == _selectedUser.username;

                  //消息行
                  return Row(
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: <Widget>[
                      Flexible(
                        child: Container(
                            padding: EdgeInsets.all(8.0),
                            margin: EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            child: SelectableText(
                              message.message,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                                fontSize: 16.0,
                              ),
                            )),
                      ),
                    ],
                  );
                },
              ),
            ),

            Container(
              child: Row(
                children: <Widget>[
                  Flexible(
                    //输入框
                    child: CupertinoTextField(
                        textInputAction: TextInputAction.send,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        controller: _textEditingController,
                        placeholder: "Enter message",
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        onSubmitted: _inputChange),
                  ),
                  //文本
                  Text(" 记住对话"),
                  //checkbox
                  Checkbox(
                    value: remember,
                    onChanged: _changeRemember,
                  ),
                  //提交按钮
                  if (isSending)
                    Center(child: CircularProgressIndicator())
                  else
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () {
                        _sendMessage(_textEditingController.text);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
