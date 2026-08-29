package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/xfn/text-vault/internal/auth"
	"github.com/xfn/text-vault/internal/httpapi"
	"github.com/xfn/text-vault/internal/store"
	"github.com/xfn/text-vault/web"
)

func main() {
	cfg, err := parseConfig(os.Args[1:], os.Getenv)
	if err != nil {
		slog.Error("invalid configuration", "error", err)
		os.Exit(2)
	}
	database, err := store.Open(cfg.database)
	if err != nil {
		slog.Error("database failed", "error", err)
		os.Exit(1)
	}
	defer database.Close()
	sessions, err := auth.New(cfg.accessToken, cfg.secureCookie)
	if err != nil {
		slog.Error("authentication failed", "error", err)
		os.Exit(2)
	}

	server := &http.Server{
		Addr: cfg.listen,
		Handler: httpapi.New(httpapi.Config{
			Frontend: web.FS,
			Store:    database,
			Auth:     sessions,
		}),
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

type config struct {
	listen       string
	database     string
	accessToken  string
	secureCookie bool
}

func parseConfig(args []string, getenv func(string) string) (config, error) {
	flags := flag.NewFlagSet("text-vault", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	var cfg config
	flags.StringVar(&cfg.listen, "listen", "127.0.0.1:8080", "HTTP listen address")
	flags.StringVar(&cfg.database, "database", "./data/text-vault.db", "SQLite database path")
	flags.BoolVar(&cfg.secureCookie, "secure-cookie", true, "require HTTPS session cookies")
	if err := flags.Parse(args); err != nil {
		return config{}, err
	}
	cfg.accessToken = getenv("TEXT_VAULT_ACCESS_TOKEN")
	if cfg.accessToken == "" {
		return config{}, errors.New("TEXT_VAULT_ACCESS_TOKEN is required")
	}
	if flags.NArg() != 0 {
		return config{}, fmt.Errorf("unexpected arguments: %v", flags.Args())
	}
	return cfg, nil
}
