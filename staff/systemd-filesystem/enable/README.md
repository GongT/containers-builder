# 配置启动服务组件

输入参数:
* REQUIRE、WANT、BACKGROUND - 空格分割的服务名称列表

REQUIRES = 失败导致容器退出 & 成功才发送通知
WANTS = 成功、失败不会产生影响
BACKGROUND = 需要长时间运行，成功没有影响，但失败导致容器退出

所有的都会自启动
