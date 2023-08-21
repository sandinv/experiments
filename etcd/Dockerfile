FROM golang:1.20-alpine3.17 AS builder

# Set destination for COPY
WORKDIR /app

# Download Go modules
COPY go-etcd/go.mod go-etcd/go.sum ./
RUN go mod download

COPY go-etcd/*.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o /etcd-client

FROM alpine:3.17

WORKDIR /

COPY --from=builder /etcd-client /etcd-client

VOLUME /etc/ssl/certs/

ENV CLIENT_CERT="/etc/ssl/certs/client.pem" CLIENT_KEY="/etc/ssl/certs/client.key" CLIENT_CA="/etc/ssl/certs/ca.pem" ETCD_ENDPOINTS=""

ENTRYPOINT ["/etcd-client"]
