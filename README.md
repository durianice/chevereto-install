## 开始
### 1 替换 [docker-compose.yml](https://github.com/durianice/chevereto-install/blob/pure-docker/docker-compose.yml) 中的 `{{xxx}}` 为实际值
### 2 `docker compose up -d` (或 `20` 以前的版本 `docker-compose up -d`)
### 3 域名解析
### 4 Nginx (或 Caddy) 反代至 `http://127.0.0.1:8880`，具体参考[这里](https://google.com)
### 5 使用 Nginx 时注意开启文件 SIZE 限制，具体参考[这里](https://google.com)
配置示例
```
server {
    listen 80;
    server_name yourdomain.com;

    # 增加上传文件大小限制
    client_max_body_size 50M;

    location / {
        proxy_pass http://localhost:8880;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
## 官方手册
[PURE-DOCKER](https://github.com/chevereto/docker/blob/4.0/docs/PURE-DOCKER.md)
