# en-pratice-container

Docker stack để dựng nhanh server `en-practice-be` cùng các service phụ trợ trên máy local hoặc host mới.

## Mục tiêu của repo

Repo này chỉ giữ các file setup có thể tái sử dụng:

- `docker-compose.yml`
- `.env.example`
- `schema.sql`
- `openclaw/config/openclaw.json.example`

Các file runtime và secret không được track:

- `.env`
- `data/`
- `logs/`
- `docs/`
- `dump-*.sql`
- `openclaw/workspace/`
- `openclaw/config/openclaw.json`

## Stack hiện tại

`docker compose` sẽ chạy 5 service:

- `postgres`
- `redis`
- `kafka`
- `openclaw-gateway`
- `en-practice-be`

## Setup nhanh

### 1. Điều kiện cần

Máy chạy cần có:

- Docker Engine + Docker Compose
- Mở sẵn các port `5432`, `8080`, `18789`, `9092`, `9094`
- Tối thiểu khoảng 3 GB RAM trống để stack chạy ổn định

### 2. Tạo file `.env`

Copy file mẫu:

```powershell
Copy-Item .env.example .env
```

Các biến cần điền trước khi chạy:

- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- `FIREBASE_CONFIG_BASE64`
- `OPENCLAW_GATEWAY_TOKEN`
- `TTS_API_KEY`
- `BACKBLAZE_S3_ACCESS_KEY_ID`
- `BACKBLAZE_S3_SECRET_ACCESS_KEY`
- `BACKBLAZE_S3_WORKER_SHARED_SECRET`
- `KAFKA_EXTERNAL_HOST`

Giá trị nên dùng khi chạy local:

```dotenv
APP_PORT=8080
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_SSL_ENABLED=false
SPRING_CACHE_TYPE=redis

SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:9092
KAFKA_INTERNAL_HOST=kafka
KAFKA_INTERNAL_PORT=9092
KAFKA_EXTERNAL_HOST=localhost
KAFKA_EXTERNAL_PORT=9094

OPENCLAW_GATEWAY_URL=http://openclaw-gateway:18789
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
```

Nếu chạy trên server public, đổi `KAFKA_EXTERNAL_HOST` sang domain hoặc IP thật của máy.

### 3. Tạo file cấu hình OpenClaw thật

Copy file mẫu:

```powershell
Copy-Item openclaw/config/openclaw.json.example openclaw/config/openclaw.json
```

Sau đó sửa `openclaw/config/openclaw.json`:

- thay `gateway.auth.token` cho khớp với `OPENCLAW_GATEWAY_TOKEN` trong `.env`
- thay email trong `auth.profiles`
- chỉnh provider/plugin nếu môi trường của bạn cần khác file mẫu

### 4. Khởi động stack

```powershell
docker compose up -d
```

Kiểm tra trạng thái:

```powershell
docker compose ps
```

5 service cần lên:

- `postgres`
- `redis`
- `kafka`
- `openclaw-gateway`
- `en-practice-be`

### 5. Xem log nếu service chưa healthy

```powershell
docker compose logs --tail 100 postgres
docker compose logs --tail 100 redis
docker compose logs --tail 100 kafka
docker compose logs --tail 100 openclaw-gateway
docker compose logs --tail 100 en-practice-be
```

## Khởi tạo database

Nếu database còn trống, import schema:

```powershell
Get-Content schema.sql | docker exec -i en_practice_postgres psql -U en_practice -d en_practice
```

Nếu cần restore từ file dump:

```powershell
Get-Content .\dump-en_practice-202604240902.sql | docker exec -i en_practice_postgres psql -U en_practice -d en_practice
```

Nếu bạn đã đổi `POSTGRES_DB` hoặc `POSTGRES_USER` trong `.env`, sửa lại lệnh cho đúng.

## Kiểm tra nhanh sau khi chạy

Health của OpenClaw:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:18789/healthz
```

Health của backend:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8080/actuator/health
```

Địa chỉ truy cập:

- OpenClaw gateway: `http://localhost:18789`
- Backend: `http://localhost:8080`

## Lệnh vận hành thường dùng

Khởi động lại toàn bộ stack:

```powershell
docker compose restart
```

Dừng stack:

```powershell
docker compose down
```

Dừng stack và xóa volume Kafka:

```powershell
docker compose down -v
```

## Ghi chú triển khai

- `en-practice-be` dùng image từ `DOCKER_HUB_IMAGE` và `APP_VERSION` trong `.env`
- `postgres` lưu data vào `data/postgres`
- log backend được mount tại `logs/app`
- OpenClaw config thật nằm ở `openclaw/config/openclaw.json` và không được commit
- `cloudflared` hiện không nằm trong compose; nếu cần tunnel thì cấu hình đang ở `C:\Users\sonpt1\.cloudflared\config.yml`
