# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 复制go mod文件
COPY backend/go.mod backend/go.sum ./
RUN go mod download

# 复制源代码
COPY backend/ ./

# 构建应用 - MySQL驱动不需要额外的CGO设置
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# 运行阶段
FROM alpine:latest

# 安装必要的包
RUN apk --no-cache add ca-certificates

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/main .
COPY --from=builder /app/database ./database

# 复制前端文件
COPY frontend/templates ./templates
COPY frontend/static ./static

# 创建必要的目录
RUN mkdir -p users shared workspace

# 暴露端口
EXPOSE 8080

# 运行应用
CMD ["./main"]