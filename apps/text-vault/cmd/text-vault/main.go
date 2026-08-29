package main

import (
	"context"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/xfn/text-vault/internal/httpapi"
	"github.com/xfn/text-vault/web"
)

func main() {
	listen := flag.String("listen", "127.0.0.1:8080", "HTTP listen address")
	_ = flag.String("database", "./data/text-vault.db", "SQLite database path")
	flag.Parse()

	server := &http.Server{
		Addr:              *listen,
		Handler:           httpapi.New(httpapi.Config{Frontend: web.FS}),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	slog.Info("text-vault listening", "address", server.Addr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}
