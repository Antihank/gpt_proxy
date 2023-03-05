# gpt_proxy

- 一个简单的python服务，转发并存储消息，提供查看对话列表和历史消息的能力。
   - 数据存储到sqlite。
- 一个简单的flutter客户端，接上面那个python服务端。

# how to use
- 搞个vps
- 搞个域名(可选)
- python服务里填openai的key
- flutter里填域名或ip地址
- 部署python，版本3.7.16
- flutter编译，随便什么客户端
   - 要不就部署到服务端，用web访问
   - 要不就编译成ios或者andriod，随便你
- 玩。
