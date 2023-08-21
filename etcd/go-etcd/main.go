package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/nicholasjackson/env"
	"go.etcd.io/etcd/api/v3/v3rpc/rpctypes"
	clientv3 "go.etcd.io/etcd/client/v3"
)

var (
	endpoints = env.String("ETCD_ENDPOINTS", true, "", "the etcd endpoints to connect to joint by commas")
	clientPem = env.String("CLIENT_CERT", true, "", "the client certificate used for connecting to etcd")
	clientKey = env.String("CLIENT_KEY", true, "", "the client certificate key used for connecting to etcd")
	clientCA  = env.String("CLIENT_CA", true, "", "the client certificate authority")
	appLogger hclog.Logger
)

func main() {
	appLogger = hclog.New(&hclog.LoggerOptions{
		Name:  "go-ectd",
		Level: hclog.LevelFromString("DEBUG"),
	})
	err := env.Parse()
	if err != nil {
		appLogger.Error("could not parse env vars")
		os.Exit(1)
	}

	cfg, err := parseCertificates()
	if err != nil {
		appLogger.Error("could not build tls Config", "error", err)
		os.Exit(1)
	}

	cli, err := clientv3.New(clientv3.Config{
		Endpoints:         strings.Split(*endpoints, ","),
		DialTimeout:       2 * time.Second,
		DialKeepAliveTime: 2 * time.Second,
		TLS:               cfg,
	})

	if err != nil {
		appLogger.Error("could not establish connection with the etcd endpoints", "error", err)
		os.Exit(1)
	}
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())

	c := make(chan os.Signal, 1)
	abort := make(chan struct{}, 1)
	signal.Notify(c, os.Interrupt)

	appLogger.Info("starting to write to etcd cluster")
	go func() {
		for {
			c, _ := context.WithTimeout(ctx, 1*time.Second)
			resp, err := cli.Put(c, "cur_date", time.Now().Format(time.RFC3339))
			if err != nil {
				switch {
				case errors.Is(err, context.DeadlineExceeded):
					appLogger.Error("timeout while writing to etcd", "error", err)
					abort <- struct{}{}
					return
				case errors.Is(err, context.Canceled):
					appLogger.Error("aborting operation", "error", err)
					abort <- struct{}{}
					return
				case errors.Is(err, rpctypes.ErrEmptyKey):
					appLogger.Error("client-side error", "error", err)
				default:
					appLogger.Error("bad cluster endpoints, which are not etcd servers", "error", err)
					abort <- struct{}{}
				}
			}
			appLogger.Info("succesfull write", "memberID", resp.Header.MemberId, "clusterID", resp.Header.ClusterId)
			time.Sleep(3 * time.Second)
		}
	}()
	select {
	case <-c:
		appLogger.Info("shutting down the client")
		cancel()
	case <-abort:
		appLogger.Info("aborting operation due to an error")
	}
}

func parseCertificates() (*tls.Config, error) {

	certPem, err := os.ReadFile(*clientPem)
	if err != nil {
		return &tls.Config{}, fmt.Errorf("could not read client certificate: %s", err)
	}

	keyPem, err := os.ReadFile(*clientKey)
	if err != nil {
		return &tls.Config{}, fmt.Errorf("could not read client key: %s", err)
	}

	cert, err := tls.X509KeyPair(certPem, keyPem)
	if err != nil {
		return &tls.Config{}, fmt.Errorf("could not build the X509 key pair: %s", err)
	}

	caPem, err := os.ReadFile(*clientCA)
	if err != nil {
		return &tls.Config{}, fmt.Errorf("could not read client key: %s", err)
	}

	rootCAs, err := x509.SystemCertPool()
	if err != nil {
		return &tls.Config{}, fmt.Errorf("could not get system cert pool: %s", err)
	}

	if rootCAs == nil {
		rootCAs = x509.NewCertPool()
	}

	ok := rootCAs.AppendCertsFromPEM(caPem)
	if !ok {
		return &tls.Config{}, fmt.Errorf("could not add the ca cert to system cert pool: %s", err)
	}

	return &tls.Config{
		Certificates: []tls.Certificate{cert},
		RootCAs:      rootCAs,
	}, nil
}
