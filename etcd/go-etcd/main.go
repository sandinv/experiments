package main

import (
	"context"
	"errors"
	"os"
	"os/signal"
	"strings"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/nicholasjackson/env"
	"go.etcd.io/etcd/api/v3/v3rpc/rpctypes"
	clientv3 "go.etcd.io/etcd/client/v3"
)

var endpoints = env.String("ETCD_ENDPOINTS", true, "", "the etcd endpoints to connect to joint by commas")

func main() {
	appLogger := hclog.New(&hclog.LoggerOptions{
		Name:  "go-ectd",
		Level: hclog.LevelFromString("DEBUG"),
	})
	err := env.Parse()
	if err != nil {
		appLogger.Error("could not parse env vars")
		os.Exit(1)
	}

	cli, err := clientv3.New(clientv3.Config{
		Endpoints:         strings.Split(*endpoints, ","),
		DialTimeout:       2 * time.Second,
		DialKeepAliveTime: 2 * time.Second,
	})
	if err != nil {
		appLogger.Error("could not establish connection with the etcd endpoints", "error", err)
		os.Exit(1)
	}
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)

	appLogger.Info("starting to write to etcd cluster")
	go func() {
		for {
			resp, err := cli.Put(ctx, "cur_date", time.Now().Format(time.RFC3339))
			if err != nil {
				switch {
				case errors.Is(err, context.Canceled):
					appLogger.Error("ctx is canceled by another routine", "error", err)
					return
				case errors.Is(err, rpctypes.ErrEmptyKey):
					appLogger.Error("client-side error", "error", err)
				default:
					appLogger.Error("bad cluster endpoints, which are not etcd servers", "error", err)
				}
			}
			appLogger.Info("succesfull write", "memberID", resp.Header.MemberId, "clusterID", resp.Header.ClusterId)
			time.Sleep(3 * time.Second)
		}
	}()
	<-c
	cancel()
}
