# Deploy Mosaic bằng Docker + Cloudflare Tunnel

Chạy lệnh trong thư mục gốc của repo (cùng cấp với `compose.yaml`). Cần Docker Engine
và Docker Compose v2 hoặc mới hơn, ở chế độ Linux containers.

Luồng truy cập: **HTTPS → Cloudflare → cloudflared → http://web:8080**.
Compose không publish port nào ra host. `web` chỉ nằm trong mạng `origin` nội bộ;
`cloudflared` nối mạng này với mạng `edge` có kết nối Internet. Ảnh vẫn xử lý hoàn
toàn trong trình duyệt. Không có database, volume ảnh hay dịch vụ upload phía server.

## 1. Chuẩn bị token

Tạo một remotely-managed Cloudflare Tunnel và lấy **tunnel token** trong dashboard.
Đây không phải API token cấp tài khoản. Lưu duy nhất token vào
`secrets/cloudflare-tunnel-token.txt` bằng trình soạn thảo, UTF-8 không BOM.
Xem [quyền truy cập file secret](secrets/README.md). Không đưa token vào Git.

Không cần `.env` nếu dùng mặc định. Nếu muốn đổi tên project, đường dẫn secret hoặc
image, sao chép `.env.example` thành `.env` và sửa các giá trị tương ứng.

## 2. Cấu hình hostname trong Cloudflare

Trong tunnel, thêm **Published application route / Public hostname**:

- Hostname: tên miền/subdomain bạn muốn dùng, ví dụ `photos.example.com`.
- Service type: **HTTP**.
- Service URL: **`web:8080`** (tương đương `http://web:8080`).
- Path: để trống nếu phục vụ cả website.

Không dùng `localhost:8080`: trong container tunnel, localhost là chính cloudflared.
HTTPS kết thúc tại Cloudflare; chặng origin là HTTP trong mạng Docker.
Nếu chỉ muốn bạn hoặc một nhóm truy cập, thiết lập Cloudflare Access cho hostname;
bản Docker không tự kế thừa quyền riêng tư của bản Sites.

Máy chủ cần kết nối đi ra Cloudflare (mặc định UDP/TCP 7844 và DNS). Không cần NAT,
port-forward hay mở inbound 80/443/8080. Token chạy connector; token không tự tạo
hostname/route, nên phải hoàn thành bước cấu hình route riêng.

## 3. Khởi động

```sh
docker compose config --quiet
docker compose up -d --build --wait --wait-timeout 120
docker compose ps
docker compose logs --tail=50 cloudflared
```

`web` phải healthy trước khi tunnel khởi động. Healthcheck của cloudflared kiểm tra
kết nối tunnel qua endpoint `/ready`; `--wait` chờ cả hai dịch vụ healthy.
Sau khi tunnel kết nối, mở hostname
HTTPS đã cấu hình và thử thêm ảnh/xuất ảnh. Chưa có token thì chỉ chạy origin:

```sh
docker compose up -d --build --wait web
docker compose exec -T web wget -qO- http://127.0.0.1:8080/healthz
```

Lệnh trên không mở port; health endpoint trả về `ok`. Để kiểm tra cả mạng Compose
(DNS `web` và HTTP) mà không cần token:

```sh
docker compose run --rm --no-deps --entrypoint wget web -qO- http://web:8080/healthz
```

## Vận hành

Image mặc định đã khóa bằng digest để cùng mã nguồn cho cùng phiên bản image.
Muốn nâng phiên bản, cập nhật digest/tag trong `.env` trước khi pull/build.

```sh
# Cập nhật website sau khi thay mã nguồn
docker compose up -d --build --wait

# Cập nhật image theo các phiên bản đã chọn trong Compose/.env
docker compose pull cloudflared
docker compose build --pull web
docker compose up -d --wait

# Sau khi thay token: tạo lại container để secret được mount lại
docker compose up -d --force-recreate cloudflared

# Xem log hoặc dừng riêng project này
docker compose logs --tail=100 web cloudflared
docker compose down
```

Nginx chạy user không phải root, filesystem chỉ đọc với `/tmp` tạm, log xoay vòng.
Cloudflared cũng chạy filesystem chỉ đọc, không có Docker socket hoặc quyền đặc biệt.
Các file JS/CSS revalidate khi mở lại trang để nhận bản cập nhật.

## Kiểm tra bộ triển khai

Không cần Docker engine (chỉ cần CLI Compose):

```sh
node --test tests/deployment.test.mjs
```

Khi Docker engine hoạt động, kiểm thử image thật, HTTP, DNS nội bộ và không mở port:

```sh
node tests/docker-smoke.mjs
```

Script dùng project tạm riêng, tự dọn các container/mạng do nó tạo và không chạy
tunnel ra Internet. Việc xác thực Cloudflare và hostname phải thử lại sau khi có token.

## Tài liệu chính thức

- [Cloudflare: token-file và tham số tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/)
- [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Nginx unprivileged](https://github.com/nginx/docker-nginx-unprivileged)
