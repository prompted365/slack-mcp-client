########################
# 1. Build  (Go only)  #
########################
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Go deps
COPY go.mod go.sum ./
RUN go mod download

# Source
COPY . .

# (Optional, but harmless) copy config
COPY mcp-servers.json ./

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo \
    -o slack-mcp-client ./cmd/slack-mcp-client

########################
# 2. Runtime  (Alpine) #
########################
FROM alpine:3.21

# Runtime deps:
#   • ca-certificates + tzdata  – SSL & sane time
#   • nodejs + npm             – provides `npx` for the MCP stdio servers
RUN apk add --no-cache ca-certificates tzdata nodejs npm \
 && adduser -D -h /home/appuser appuser

WORKDIR /home/appuser

# Copy artifacts from builder
COPY --from=builder /app/slack-mcp-client .
COPY --from=builder /app/mcp-servers.json .

# Set sane file ownership (drop root)
RUN chown -R appuser:appuser /home/appuser
USER appuser

# Default to stdio unless you override `mode` in mcp-servers.json
ENV MCP_MODE="stdio"

ENTRYPOINT ["./slack-mcp-client"]
