# 16. 构建、部署和 Nginx

这篇笔记把两部分内容合在一起：

- 知乎文章《学习 nginx 配置，这一篇就够了》里的 Nginx 配置知识点
- 本项目从本地 Nginx 部署到阿里云 ECS 部署过程中追问到的内容

它不是按时间顺序记录，而是按“脑图式层级”组织，方便以后从整体结构回看。

## 0. 总览脑图

```text
React 项目部署
├─ 构建
│  ├─ npm run build
│  ├─ 生成 build/
│  └─ build 里是 index.html + static/*
│
├─ 本地部署
│  ├─ 安装 Nginx
│  ├─ root 指向本地 build/
│  ├─ listen 8088
│  └─ /api 反向代理到远端 API
│
├─ ECS 部署
│  ├─ SSH 登录 ECS
│  ├─ 安装 Nginx
│  ├─ 上传 build 压缩包
│  ├─ 解压到 /var/www/react-redux-realworld/html
│  ├─ 上传 Nginx 站点配置
│  └─ 访问 http://39.105.41.7/
│
└─ Nginx 核心
   ├─ nginx.conf 主配置
   ├─ sites-available/sites-enabled 站点配置
   ├─ server 定义站点
   ├─ location 定义路径规则
   ├─ root/index/try_files 返回静态文件
   ├─ proxy_pass 反向代理 API
   ├─ headers 控制响应头和缓存
   ├─ rewrite 改写 URI 或重定向
   ├─ referer 做防盗链
   └─ upstream 做后端服务器组和负载均衡
```

## 1. 部署链路

### 1.1 源码到静态文件

```text
React 源码
├─ src/
│  ├─ components/
│  ├─ features/
│  └─ app/
│
└─ npm run build
   └─ build/
      ├─ index.html
      ├─ asset-manifest.json
      ├─ favicon.ico
      └─ static/
         └─ js/css/media
```

部署时不是把 `src/` 直接交给 Nginx，而是把 `build/` 交给 Nginx。

```text
源码：
  给开发者和构建工具使用

build：
  给浏览器和 Nginx 使用
```

### 1.2 本地 Nginx 部署

本地配置文件：

```text
deploy/local-nginx.conf
```

本地 Nginx 用这个配置启动：

```json
"nginx:local:start": "/opt/homebrew/opt/nginx/bin/nginx -c $PWD/deploy/local-nginx.conf"
```

关键点：

```text
-c：
  指定 Nginx 使用哪个配置文件

$PWD：
  当前项目根目录

listen 8088：
  本地监听 8088，避免占用 80 或 8080

root：
  指向本地 build 目录
```

本地访问：

```text
http://localhost:8088/
```

### 1.3 ECS 部署

部署脚本：

```text
scripts/deploy-ecs.sh
```

执行方式：

```bash
DEPLOY_KEY=/Users/chenmeng/Downloads/测试.pem npm run deploy:ecs
```

部署流程：

```text
npm run deploy:ecs
├─ npm run build
├─ tar 打包 build/
├─ SSH 登录 ECS
├─ apt-get install nginx
├─ scp 上传 build 压缩包
├─ scp 上传 Nginx 配置
├─ 解压到 /var/www/react-redux-realworld/html
├─ 写入 /etc/nginx/sites-available/react-redux-realworld
├─ 链接到 /etc/nginx/sites-enabled/react-redux-realworld
├─ nginx -t 检查配置
└─ systemctl restart nginx
```

线上访问：

```text
http://39.105.41.7/
```

## 2. ECS、SSH 和密钥

### 2.1 ECS 是什么

ECS 全称是 `Elastic Compute Service`，中文一般叫“弹性计算服务”，在阿里云里通常叫“云服务器 ECS”。

```text
ECS
├─ 阿里云上的一台远程服务器
├─ 有 CPU、内存、磁盘、公网 IP
├─ 可以安装软件
│  ├─ Nginx
│  ├─ Node.js
│  ├─ Docker
│  └─ MySQL/Redis 等
└─ 可以 24 小时对外提供服务
```

这个项目里 ECS 的角色：

```text
ECS
├─ 安装 Nginx
├─ 保存 React build 文件
├─ 对外提供 HTTP 访问
└─ 代理 /api 请求到远端后端
```

### 2.2 SSH 是什么

SSH 用来远程登录服务器。

```bash
ssh root@39.105.41.7
```

密钥登录：

```bash
ssh -i /Users/chenmeng/Downloads/测试.pem root@39.105.41.7
```

关系：

```text
本地：
  /Users/chenmeng/Downloads/测试.pem
  私钥，必须保密

ECS：
  保存对应公钥
  用来验证你是否有权限登录
```

注意：

```text
私钥不能发给别人
私钥不能提交到 Git
私钥权限要保持 600
```

```bash
chmod 600 /Users/chenmeng/Downloads/测试.pem
```

### 2.3 安全组

安全组控制外部能访问 ECS 哪些端口。

```text
22：
  SSH 登录

80：
  HTTP 网站

443：
  HTTPS 网站
```

当前项目至少需要：

```text
22 端口：
  用来部署和登录服务器

80 端口：
  用来访问 http://39.105.41.7/
```

## 3. Nginx 配置结构

### 3.1 主配置和站点配置

ECS 上主配置：

```text
/etc/nginx/nginx.conf
```

站点配置：

```text
/etc/nginx/sites-available/react-redux-realworld
```

启用站点的软链接：

```text
/etc/nginx/sites-enabled/react-redux-realworld
  -> /etc/nginx/sites-available/react-redux-realworld
```

主配置中有：

```nginx
include /etc/nginx/sites-enabled/*;
```

所以最终关系是：

```text
/etc/nginx/nginx.conf
└─ include /etc/nginx/sites-enabled/*
   └─ react-redux-realworld
      └─ server { ... }
```

不是我们的配置覆盖主配置，而是主配置把我们的站点配置加载进来。

### 3.2 当前 ECS 主配置关键内容

```nginx
user www-data;
worker_processes auto;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

关键点：

```text
worker_processes auto：
  自动按 CPU 情况决定 worker 数量

worker_connections 768：
  每个 worker 最多处理 768 个连接

include /etc/nginx/sites-enabled/*：
  加载当前启用的站点配置
```

### 3.3 Nginx 配置层级

```text
main 层
├─ user
├─ worker_processes
├─ pid
└─ include modules

events 层
└─ worker_connections

http 层
├─ mime.types
├─ gzip
├─ access_log
├─ error_log
└─ include sites-enabled/*

server 层
├─ listen
├─ server_name
├─ root
└─ index

location 层
├─ /api/ -> proxy_pass
└─ /     -> try_files
```

## 4. 当前项目的站点配置

项目配置文件：

```text
deploy/ecs-nginx.conf
```

部署到 ECS 后变成：

```text
/etc/nginx/sites-available/react-redux-realworld
```

内容：

```nginx
server {
  listen 80;
  server_name _;

  root /var/www/react-redux-realworld/html;
  index index.html;

  location /api/ {
    proxy_pass https://conduit-api.bondaracademy.com/api/;
    proxy_ssl_server_name on;
    proxy_set_header Host conduit-api.bondaracademy.com;
    proxy_set_header Origin "";
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location / {
    try_files $uri /index.html;
  }
}
```

整体分层：

```text
server
├─ listen 80
│  └─ 监听 HTTP 默认端口
│
├─ server_name _
│  └─ 默认站点，直接访问 IP 时也匹配
│
├─ root /var/www/react-redux-realworld/html
│  └─ 静态资源目录
│
├─ index index.html
│  └─ 访问目录时默认返回 index.html
│
├─ location /api/
│  └─ 反向代理到远端 API
│
└─ location /
   └─ 真实文件存在就返回，否则返回 index.html
```

## 5. listen、端口和访问地址

### 5.1 listen 80

```nginx
listen 80;
```

意思：

```text
Nginx 在服务器的 80 端口等待 HTTP 请求
```

浏览器访问：

```text
http://39.105.41.7/
```

等价于：

```text
http://39.105.41.7:80/
```

因为 HTTP 默认端口是 80，所以浏览器省略了。

### 5.2 其他常见端口

```text
22：
  SSH

80：
  HTTP

443：
  HTTPS

8080/8088：
  常见测试端口
```

如果写：

```nginx
listen 8080;
```

就要访问：

```text
http://39.105.41.7:8080/
```

## 6. server_name 和多个项目

### 6.1 直接访问 IP 为什么会进入当前项目

当前配置：

```nginx
server_name _;
```

可以理解为默认站点。

访问：

```text
http://39.105.41.7/
```

请求到 ECS 的 80 端口，Nginx 没有更具体域名匹配，就使用这个默认 `server`。

### 6.2 多个域名可以打到同一个 Nginx

DNS：

```text
a.example.com -> 39.105.41.7
b.example.com -> 39.105.41.7
```

Nginx：

```nginx
server {
  listen 80;
  server_name a.example.com;
  root /var/www/a;
}

server {
  listen 80;
  server_name b.example.com;
  root /var/www/b;
}
```

浏览器请求时会带：

```http
Host: a.example.com
```

Nginx 根据 `Host` 匹配 `server_name`。

### 6.3 一台 ECS 部署多个项目

```text
方式一：不同域名
├─ app1.example.com -> 项目 A
└─ app2.example.com -> 项目 B

方式二：不同路径
├─ /app1/ -> 项目 A
└─ /app2/ -> 项目 B

方式三：不同端口
├─ :8081 -> 项目 A
└─ :8082 -> 项目 B
```

更推荐：

```text
一个 Nginx
多个 server/location
按域名或路径分发多个项目
```

不推荐在一台 ECS 上为了多个项目启动多个 Nginx 监听同一个 80 端口，因为同一个 IP 的同一个端口只能被一个进程监听。

## 7. root、index 和静态文件

### 7.1 root

```nginx
root /var/www/react-redux-realworld/html;
```

意思：

```text
把 /var/www/react-redux-realworld/html 当作网站根目录
```

请求：

```text
/static/js/main.67901fcd.js
```

Nginx 找：

```text
/var/www/react-redux-realworld/html/static/js/main.67901fcd.js
```

### 7.2 root 目录可以自己定义

可以改成：

```nginx
root /opt/apps/conduit/frontend;
```

但要满足：

```text
目录真实存在
里面有 index.html
Nginx 用户有读取权限
部署脚本上传目录和 root 保持一致
```

### 7.3 index

```nginx
index index.html;
```

意思：

```text
访问目录时默认返回 index.html
```

如果写：

```nginx
index index.php index.html index.htm;
```

查找顺序是：

```text
1. index.php
2. index.html
3. index.htm
```

谁先存在就返回谁。

## 8. location 和 try_files

### 8.1 location /

```nginx
location / {
  try_files $uri /index.html;
}
```

`location /` 是兜底路径规则。

大部分普通请求都会匹配它：

```text
/
/login
/article/test
/static/js/main.js
/favicon.ico
```

但更具体的：

```nginx
location /api/
```

会优先处理 `/api/tags`。

### 8.2 try_files

```nginx
try_files $uri /index.html;
```

意思：

```text
先尝试找 $uri 对应的真实文件
如果找不到，就返回 /index.html
```

请求真实静态资源：

```text
/static/js/main.67901fcd.js
```

Nginx 找：

```text
/var/www/react-redux-realworld/html/static/js/main.67901fcd.js
```

文件存在，直接返回。

请求前端路由：

```text
/login
```

Nginx 找：

```text
/var/www/react-redux-realworld/html/login
```

文件不存在，返回：

```text
/var/www/react-redux-realworld/html/index.html
```

然后 React Router 在浏览器里根据 `/login` 渲染登录页。

### 8.3 React Router 和 Nginx 的分工

```text
Nginx
├─ 负责返回 index.html 和静态资源
└─ 找不到真实文件时 fallback 到 index.html

React Router
├─ 运行在浏览器里
├─ 读取 window.location.pathname
└─ 根据 Routes 渲染组件
```

访问 `/login`：

```text
浏览器请求 /login
├─ Nginx 返回 index.html
├─ 浏览器加载 React JS
├─ BrowserRouter 读取 /login
└─ Route path="/login" 渲染 AuthScreen
```

### 8.4 纯 HTML 网站如何处理 /login

如果没有 React Router：

```text
方式一：真实文件
  /login.html

方式二：真实目录
  /login/index.html

方式三：自己写 JS 路由
  window.location.pathname 判断路径

方式四：没有文件也没有路由
  返回 404
```

React SPA 用：

```nginx
try_files $uri /index.html;
```

纯多页面 HTML 可能用：

```nginx
try_files $uri $uri.html $uri/ =404;
```

## 9. 反向代理 proxy_pass

### 9.1 当前项目的 API 代理

```nginx
location /api/ {
  proxy_pass https://conduit-api.bondaracademy.com/api/;
}
```

访问：

```text
http://39.105.41.7/api/tags
```

转发到：

```text
https://conduit-api.bondaracademy.com/api/tags
```

浏览器看来是同源请求：

```text
http://39.105.41.7/api/tags
```

实际由 Nginx 代理到远端 API。

### 9.2 proxy_pass 路径替换规则

当前：

```nginx
location /api/ {
  proxy_pass https://conduit-api.bondaracademy.com/api/;
}
```

请求：

```text
/api/tags
```

结果：

```text
https://conduit-api.bondaracademy.com/api/tags
```

如果写：

```nginx
proxy_pass https://conduit-api.bondaracademy.com/;
```

请求：

```text
/api/tags
```

结果：

```text
https://conduit-api.bondaracademy.com/tags
```

会少掉 `/api`。

如果写：

```nginx
proxy_pass https://conduit-api.bondaracademy.com;
```

没有 URI 部分，会保留原始 URI：

```text
https://conduit-api.bondaracademy.com/api/tags
```

规则：

```text
proxy_pass 后面带路径：
  用 proxy_pass 的路径替换 location 匹配前缀

proxy_pass 后面不带路径：
  保留原始 URI
```

### 9.3 proxy_set_header

```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

作用：

```text
告诉后端真实客户端信息
```

分解：

```text
X-Real-IP:
  当前 Nginx 看到的客户端 IP

X-Forwarded-For:
  代理链路上的 IP 列表

X-Forwarded-Proto:
  原始请求协议，http 或 https
```

影响：

```text
日志：
  后端能记录真实访问者 IP

风控：
  后端能按真实 IP 限流、防刷

审计：
  后端能记录操作来源

协议判断：
  后端知道用户原始访问是 HTTP 还是 HTTPS
```

注意：

```text
这些 header 可以被客户端伪造
后端只能信任来自可信代理添加的 header
```

## 10. rewrite 模块

### 10.1 rewrite 是什么

```nginx
rewrite regex replacement [flag];
```

作用：

```text
按正则匹配 URI
把 URI 改写成另一个 URI 或 URL
```

常见用途：

```text
旧 URL 迁移
统一 URL 格式
路径兼容
HTTP 跳 HTTPS
API 路径转换
```

### 10.2 内部改写和外部重定向

内部改写：

```nginx
rewrite ^/old$ /new last;
```

```text
浏览器地址栏不变
Nginx 内部用 /new 继续处理
```

外部重定向：

```nginx
rewrite ^/old$ /new permanent;
```

```text
浏览器收到 301
地址栏跳到 /new
```

### 10.3 flag

```text
last：
  停止当前 rewrite，使用新 URI 重新匹配 location

break：
  停止当前 rewrite，不重新匹配 location

redirect：
  返回 302 临时重定向

permanent：
  返回 301 永久重定向
```

### 10.4 return

```nginx
return 301 https://$host$request_uri;
```

意思：

```text
直接结束请求
返回 301 永久重定向
跳到 https://原域名+原路径
```

变量：

```text
$host：
  当前请求域名或 IP

$request_uri：
  原始路径和查询参数
```

例子：

```text
http://demo.example.com/login?from=home
```

跳到：

```text
https://demo.example.com/login?from=home
```

状态码：

```text
301：
  永久重定向，浏览器和搜索引擎可能缓存

302：
  临时重定向
```

## 11. headers 模块

### 11.1 headers 模块做什么

```text
headers 模块
├─ add_header：增加响应头
└─ expires：控制缓存过期时间
```

### 11.2 add_header

```nginx
add_header X-App-Name "react-redux-realworld" always;
```

响应会多：

```http
X-App-Name: react-redux-realworld
```

`always` 表示不管 200、404、500 都尽量添加。

常见安全 header：

```nginx
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

含义：

```text
X-Content-Type-Options:
  不让浏览器乱猜 Content-Type

X-Frame-Options:
  限制 iframe 嵌入，降低点击劫持

Referrer-Policy:
  控制 Referer 信息暴露范围
```

### 11.3 expires

```nginx
expires 30d;
```

作用：

```text
设置 Expires 和 Cache-Control
让浏览器缓存资源
```

React 项目建议：

```nginx
location /static/ {
  expires 30d;
  add_header Cache-Control "public";
}

location = /index.html {
  expires -1;
  add_header Cache-Control "no-cache";
}
```

原因：

```text
/static/：
  JS/CSS 文件名带 hash，可以长缓存

index.html：
  入口文件引用最新 JS，不能长缓存
```

## 12. referer 模块

### 12.1 Referer 是什么

浏览器请求资源时可能带：

```http
Referer: http://example.com/article
```

它表示：

```text
这个请求是从哪个页面发起的
```

注意 HTTP 标准里拼写是：

```text
Referer
```

### 12.2 referer 模块用途

主要用于：

```text
防盗链
```

比如别人网站引用你的图片：

```html
<img src="http://your-site.com/images/a.png" />
```

会消耗你的流量。

### 12.3 valid_referers

```nginx
location /images/ {
  valid_referers none blocked server_names *.example.com;

  if ($invalid_referer) {
    return 403;
  }
}
```

含义：

```text
none：
  允许没有 Referer 的请求，比如用户直接打开图片

blocked：
  允许 Referer 被隐藏或删除的请求

server_names：
  允许当前 server_name 中的域名

*.example.com：
  允许 example.com 的子域名

$invalid_referer：
  如果来源不合法，则为 1
```

注意：

```text
Referer 可以被伪造
适合普通防盗链
不适合做强安全认证
```

## 13. upstream 模块

### 13.1 upstream 是什么

```nginx
upstream backend {
  server 10.0.0.1:3000;
  server 10.0.0.2:3000;
}

location /api/ {
  proxy_pass http://backend;
}
```

作用：

```text
定义一组后端服务器
让 Nginx 把请求分发给它们
```

### 13.2 负载均衡方式

```text
默认轮询：
  请求依次分配给后端

weight：
  权重大分配更多请求

ip_hash：
  按客户端 IP 固定到某台服务器

least_conn：
  分配给当前连接数最少的服务器

random：
  随机分配
```

### 13.3 当前项目是否需要 upstream

当前项目只代理到一个远端 API：

```text
https://conduit-api.bondaracademy.com/api
```

所以不需要 upstream。

如果以后有多个自己的后端实例，才需要。

## 14. FastCGI 模块

### 14.1 FastCGI 是什么

```text
Nginx 本身不执行 PHP
它可以把 .php 请求转给 PHP-FPM
PHP-FPM 执行后把结果返回给 Nginx
```

典型配置：

```nginx
location ~ \.php($|/) {
  fastcgi_pass unix:/dev/shm/php.sock;
  fastcgi_index index.php;
  include fastcgi.conf;
}
```

### 14.2 当前项目是否需要 FastCGI

不需要。

当前项目是：

```text
React 静态文件
+ Nginx 反向代理远端 API
```

没有 PHP 或 FastCGI 后端。

## 15. HTTPS

### 15.1 支持 HTTPS 需要什么

```text
1. 域名
2. 域名解析到 ECS
3. SSL/TLS 证书
4. 安全组开放 443
5. Nginx listen 443 ssl
```

### 15.2 HTTP 跳 HTTPS

```nginx
server {
  listen 80;
  server_name demo.example.com;

  return 301 https://$host$request_uri;
}
```

真正服务 HTTPS：

```nginx
server {
  listen 443 ssl;
  server_name demo.example.com;

  ssl_certificate /etc/letsencrypt/live/demo.example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/demo.example.com/privkey.pem;

  root /var/www/react-redux-realworld/html;

  location / {
    try_files $uri /index.html;
  }
}
```

没有域名时，不建议正式做 HTTPS。裸 IP 通常只能用自签证书，浏览器会提示不安全。

## 16. 重新部署和 Nginx 重启

### 16.1 只更新静态文件

```text
不一定需要重启 Nginx
```

因为 Nginx 每次请求都会从目录里读文件。

### 16.2 修改 Nginx 配置

需要：

```bash
nginx -t
systemctl reload nginx
```

或：

```bash
systemctl restart nginx
```

区别：

```text
reload：
  重新加载配置，更温和

restart：
  停掉再启动，更直接
```

当前脚本用 `restart` 是为了简单可靠。后续可以优化成配置变化时 `reload`，只更新静态文件时不重启。

## 17. 常用排查命令

### 17.1 查看 Nginx 配置

```bash
cat /etc/nginx/nginx.conf
cat /etc/nginx/sites-available/react-redux-realworld
ls -la /etc/nginx/sites-enabled
```

### 17.2 检查配置语法

```bash
nginx -t
```

### 17.3 查看服务状态

```bash
systemctl status nginx --no-pager
```

### 17.4 查看端口监听

```bash
ss -ltnp | grep ':80'
```

### 17.5 查看日志

```bash
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### 17.6 查看响应头

```bash
curl -I http://39.105.41.7/
curl -I http://39.105.41.7/login
curl -I http://39.105.41.7/static/js/main.67901fcd.js
```

### 17.7 查看 API 代理

```bash
curl http://39.105.41.7/api/tags
```

## 18. 最终理解模型

```text
浏览器访问页面
├─ http://39.105.41.7/
├─ 请求到 ECS 的 80 端口
├─ Nginx listen 80 接收
├─ location / 匹配
├─ root 找到 index.html
├─ 返回 React build 文件
└─ React Router 渲染页面
```

```text
浏览器访问前端路由
├─ http://39.105.41.7/login
├─ Nginx 找 /var/www/.../login
├─ 找不到
├─ try_files 返回 index.html
├─ React Router 读取 /login
└─ 渲染 AuthScreen
```

```text
浏览器访问 API
├─ http://39.105.41.7/api/tags
├─ location /api/ 匹配
├─ proxy_pass 到远端后端
├─ Nginx 收到远端 JSON
└─ 返回给浏览器
```

一句话总结：

```text
Nginx 在这个项目里既是静态文件服务器，也是反向代理。
它负责把 React build 文件交给浏览器，把 /api 请求转发给后端；
真正的页面切换由浏览器里的 React Router 完成。
```
