# 端口转发组件

将容器内监听的端口转发到指定的公开 unix socket

输入参数:
* PORTS - 端口转发定义列表，格式为 `[name:]port_number[/protocol]`，必填，空格分隔多个定义
 	* name - 端口转发的名称，可选，默认是端口号
 	* port_number - 容器内监听的端口号，必填
 	* protocol - 协议类型，默认是 tcp，可设为 udp

socket文件存放于 /run/sockets 目录下。注意多个容器间不要使用相同的 socket 名称，以避免冲突。
