# 基本systemd配置组件

没有输入参数，必须在所有其他组件之前添加

在容器内提供
* entrypoint
* 预启动hook
* 重载
* 成功通知服务（默认无依赖）
* emergency和shell参数启动bash

## 通知功能

入口脚本将 NOTIFY_SOCKET 保存到 __NOTIFY_SOCKET__，然后删除 NOTIFY_SOCKET 变量

systemd本身支持启动完成后通知服务状态，但它要求所有服务都正常启动，实际并不一定满足

所以我们删除此变量来禁止systemd对启动完成的通知，改为需要时手动实现，当success.service被启用时，它会使用 __NOTIFY_SOCKET__ 来通知服务状态

随时可以用 systemd-host-notify 来发送额外通知

## 环境变量

* CONTAINER_DIGITS_LONG - 64字符容器ID，同时可从 /etc/machine-id 获取
* CONTAINER_DIGITS_SHORT - 12字符容器ID
* CONTAINER_ID - 实际是容器名称
* /etc/environment /run/.userenvironments

## 服务
执行顺序:

1. systemd
1. why-not-success.service
1. 各种自定义服务
1. notify-stop.service
1. success.service

* success.service - 运行时发送通知，需添加Requires，After包含notify-stop所以不需要额外添加
* notify-stop.service - 启动noop，停止时发送通知，需添加After，不可添加Requires
* why-not-success.service - 启动noop，容器最终退出前显示 success.service 启动失败的原因（即列出它依赖失败的服务）
