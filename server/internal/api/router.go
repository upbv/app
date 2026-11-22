package api

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/piter/dashboard/server/internal/collector"
	"github.com/piter/dashboard/server/internal/store"
	"github.com/piter/dashboard/server/internal/ws"
)

// Router wires the HTTP endpoints used by the desktop and mobile clients.
type Router struct {
	store *store.Store
	hub   *ws.Hub
	cors  string
}

func NewRouter(st *store.Store, hub *ws.Hub, corsOrigin string) *Router {
	return &Router{store: st, hub: hub, cors: corsOrigin}
}

func (rt *Router) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", rt.health)
	mux.HandleFunc("/api/host", rt.host)
	mux.HandleFunc("/api/metrics/current", rt.metricsCurrent)
	mux.HandleFunc("/api/metrics/history", rt.metricsHistory)
	mux.HandleFunc("/api/volumes", rt.volumes)
	mux.HandleFunc("/api/services", rt.services)
	mux.HandleFunc("/api/disks", rt.disks)
	mux.HandleFunc("/api/sensors", rt.sensors)
	mux.Handle("/ws", rt.hub)
	return withCORS(mux, rt.cors)
}

func withCORS(next http.Handler, origin string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if origin == "*" {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		} else if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type,Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("encode: %v", err)
	}
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func (rt *Router) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"host":    collector.HostName(),
		"clients": rt.hub.Count(),
		"time":    time.Now(),
	})
}

func (rt *Router) host(w http.ResponseWriter, r *http.Request) {
	info, err := collector.HostInformation()
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, info)
}

func (rt *Router) metricsCurrent(w http.ResponseWriter, r *http.Request) {
	c := collector.New(rt.store, rt.hub)
	s, err := c.Collect()
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, s)
}

// metricsHistory returns stored samples for the last N minutes.
func (rt *Router) metricsHistory(w http.ResponseWriter, r *http.Request) {
	minutes := 60
	if v := r.URL.Query().Get("minutes"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 60*24*30 {
			minutes = n
		}
	}
	host := r.URL.Query().Get("host")
	if host == "" {
		host = collector.HostName()
	}

	rows, err := rt.store.DB().Query(`
		SELECT collected_at, cpu_percent, mem_used, mem_total, disk_used, disk_total, net_rx, net_tx, temp_c, load1
		FROM metric_samples
		WHERE host = ? AND collected_at >= DATE_SUB(NOW(3), INTERVAL ? MINUTE)
		ORDER BY collected_at ASC`, host, minutes)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	type point struct {
		CollectedAt time.Time `json:"collectedAt"`
		CPUPercent  float64   `json:"cpuPercent"`
		MemUsed     uint64    `json:"memUsed"`
		MemTotal    uint64    `json:"memTotal"`
		DiskUsed    uint64    `json:"diskUsed"`
		DiskTotal   uint64    `json:"diskTotal"`
		NetRx       uint64    `json:"netRx"`
		NetTx       uint64    `json:"netTx"`
		TempC       *float64  `json:"tempC,omitempty"`
		Load1       float64   `json:"load1"`
	}

	out := make([]point, 0, 256)
	for rows.Next() {
		var p point
		if err := rows.Scan(&p.CollectedAt, &p.CPUPercent, &p.MemUsed, &p.MemTotal,
			&p.DiskUsed, &p.DiskTotal, &p.NetRx, &p.NetTx, &p.TempC, &p.Load1); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		out = append(out, p)
	}
	writeJSON(w, http.StatusOK, out)
}

func (rt *Router) volumes(w http.ResponseWriter, r *http.Request) {
	vols, err := collector.Volumes()
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, vols)
}

func (rt *Router) services(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodPost {
		rt.serviceAction(w, r)
		return
	}
	services, err := collector.ListServices()
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, services)
}

// serviceAction starts, stops or restarts a container.
func (rt *Router) serviceAction(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ID     string `json:"id"`
		Action string `json:"action"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if body.ID == "" {
		writeErr(w, http.StatusBadRequest, "id is required")
		return
	}
	out, err := collector.ContainerAction(body.ID, body.Action)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error(), "output": out})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"id": body.ID, "action": body.Action, "output": out})
}

func (rt *Router) disks(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, collector.Disks())
}

func (rt *Router) sensors(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"temperatures": collector.Temperatures(),
		"fans":         collector.Fans(),
	})
}

