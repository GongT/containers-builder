# networkd组件

暂时使用自定义的service文件，原版有一些Capability问题，等待解决后恢复

输入参数:
* ONLINE - 如果设为 yes，则会启动 systemd-networkd-wait-online.service

不修改任何success相关设置，需自定义服务自行依赖 systemd-networkd-wait-online.service

网络设置也需要各个服务自行解决
