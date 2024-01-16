# reload dir

write file in this directory. On `reload`, it will:

* if file is empty: systemctl reload `basename $file`
* if file has content: be executed by bash
