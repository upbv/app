package collector

import (
	"context"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/piter/dashboard/server/internal/store"
	"github.com/piter/dashboard/server/internal/ws"
)

// Sample is one point of system telemetry.
type Sample struct {
	Host        string    `json:"host"`
	CollectedAt time.Time `json:"collectedAt"`
	CPUPercent  float64   `json:"cpuPercent"`
	Load1       float64   `json:"load1"`
	MemUsed     uint64    `json:"memUsed"`
	MemTotal    uint64    `json:"memTotal"`
	DiskUsed    uint64    `json:"diskUsed"`
	DiskTotal   uint64    `json:"diskTotal"`
	NetRx       uint64    `json:"netRx"`
	NetTx       uint64    `json:"netTx"`
	TempC       *float64  `json:"tempC,omitempty"`
}

// Collector periodically samples the local machine and publishes to the hub.
type Collector struct {
	store *store.Store
	hub   *ws.Hub

	mu      sync.Mutex
	lastNet struct {
		rx, tx uint64
		at     time.Time
	}
}

func New(st *store.Store, hub *ws.Hub) *Collector {
	return &Collector{store: st, hub: hub}
}

func (c *Collector) Run(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	c.sampleOnce(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			c.sampleOnce(ctx)
		}
	}
}

func (c *Collector) sampleOnce(ctx context.Context) {
	s, err := c.Collect()
	if err != nil {
		log.Printf("collect: %v", err)
		return
	}
	c.hub.Publish("metrics", s)
	c.persist(ctx, s)
}

func (c *Collector) persist(ctx context.Context, s Sample) {
	_, err := c.store.DB().ExecContext(ctx, `
		INSERT INTO metric_samples
			(host, collected_at, cpu_percent, mem_used, mem_total, disk_used, disk_total, net_rx, net_tx, temp_c, load1)
		VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
		s.Host, s.CollectedAt, s.CPUPercent, s.MemUsed, s.MemTotal,
		s.DiskUsed, s.DiskTotal, s.NetRx, s.NetTx, s.TempC, s.Load1)
	if err != nil {
		log.Printf("persist sample: %v", err)
	}
}

// HostName returns the identifier used for this machine in the database.
func HostName() string {
	h, err := os.Hostname()
	if err != nil || strings.TrimSpace(h) == "" {
		return "localhost"
	}
	return h
}
