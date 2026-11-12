# 重载hook目录

在此目录中写入文件。在执行**默认** `reload` 时，它将：

* 如果文件为空: 执行 `systemctl reload $(basename $file)`
* 如果文件有内容: 由 bash 执行它，无论是否可执行、以何种扩展名结尾（但md除外）
