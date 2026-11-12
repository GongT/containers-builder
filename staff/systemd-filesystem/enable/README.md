# 配置启动服务组件

输入参数:
* REQUIRE - 空格分割的服务名称列表，添加到 success.service 的 Requires
* WANT - 空格分割的服务名称列表，添加到 success.service 的 Wants

两者均会添加到 notify-stop.service 的 After，并且调用 systemctl enable

启动前向 /entrypoint/systemd.enables.d/{requires,wants} 写入相应的文件（服务名称做文件名，内容无意义），可以动态增减依赖关系

一旦systemd启动，再写入无效
