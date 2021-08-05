package main

import (
	"fmt"
	"github.com/heptiolabs/healthcheck"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	fmt.Print(buildPrintStr())
	fmt.Print("\n")

	health := healthcheck.NewHandler()

	// Normally /metrics would be on a diff port
	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/-/ready", health.ReadyEndpoint)
	http.HandleFunc("/-/healthy", health.LiveEndpoint)


	fmt.Print("Starting http server on :8080\n")
	_ = http.ListenAndServe(":8080", nil)
}

func buildPrintStr() string {
	return "Hello World"
}
