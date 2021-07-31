package main

import (
	"fmt"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	fmt.Print(buildPrintStr())
	fmt.Print("\n")

	http.Handle("/metrics", promhttp.Handler())

	fmt.Print("Starting http server on :8080\n")
	_ = http.ListenAndServe(":8080", nil)
}

func buildPrintStr() string {
	return "Hello World"
}
