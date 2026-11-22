package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/piter/dashboard/server/internal/api"
	"github.com/piter/dashboard/server/internal/collector"
	"github.com/piter/dashboard/server/internal/store"
	"github.com/piter/dashboard/server/internal/ws"
)

func main() {
	var (
		addr      = flag.String("addr", envOr("DASH_ADDR", ":9747"), "listen address")
		dbDSN     = flag.String("db", envOr("DASH_DB_DSN", "root:login@tcp(127.0.0.1:3306)/dashboard?parseTime=true&loc=Local&charset=utf8mb4"), "mysql dsn")
		allowOrig = flag.String("cors", envOr("DASH_CORS", "*"), "cors allow origin")
	)
	flag.Parse()

	st, err := store.New(*dbDSN)
	if err != nil {
		log.Fatalf("store: %v", err)
	}
	defer st.Close()

	if err := st.Migrate(context.Background()); err != nil {
		log.Fatalf("migrate: %v", err)
	}
	log.Printf("store ready")

	hub := ws.NewHub()
	go hub.Run()

	col := collector.New(st, hub)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go col.Run(ctx, 5*time.Second)

	srv := &http.Server{
		Addr:              *addr,
		Handler:           api.NewRouter(st, hub, *allowOrig).Handler(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("dashboard api listening on %s", *addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
	hub.Close()
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
