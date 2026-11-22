package collector

import (
	"os"
	"strings"
	"time"

	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/disk"
	"github.com/shirou/gopsutil/v4/host"
	"github.com/shirou/gopsutil/v4/mem"
	"github.com/shirou/gopsutil/v4/net"
)

// Collect gathers a full telemetry sample from the local machine.
func (c *Collector) Collect() (Sample, error) {
	s := Sample{
		Host:        HostName(),
		CollectedAt: time.Now(),
	}

	percents, err := cpu.Percent(0, false)
	if err == nil && len(percents) > 0 {
		s.CPUPercent = percents[0]
	}

	vm, err := mem.VirtualMemory()
	if err == nil {
		s.MemUsed = vm.Used
		s.MemTotal = vm.Total
	}

	du, err := disk.Usage("/")
	if err == nil {
		s.DiskUsed = du.Used
		s.DiskTotal = du.Total
	}

	if load, err := avgLoad(); err == nil {
		s.Load1 = load
	}

	// Network counters are cumulative; report per-second deltas instead.
	if counters, err := net.IOCounters(false); err == nil && len(counters) > 0 {
		rx, tx := counters[0].BytesRecv, counters[0].BytesSent
		c.mu.Lock()
		prev, prevAt := c.lastNet.rx, c.lastNet.at
		c.lastNet.rx, c.lastNet.tx, c.lastNet.at = rx, tx, time.Now()
		c.mu.Unlock()

		if !prevAt.IsZero() {
			if dt := s.CollectedAt.Sub(prevAt).Seconds(); dt > 0 {
				if rx >= prev {
					s.NetRx = uint64(float64(rx-prev) / dt)
				}
				if tx >= c.lastNet.tx {
					s.NetTx = uint64(float64(tx-c.lastNet.tx) / dt)
				}
			}
		}
	}

	if t, ok := cpuTemp(); ok {
		s.TempC = &t
	}

	return s, nil
}

// HostInfo describes the operating system and uptime of this machine.
type HostInfo struct {
	Host          string    `json:"host"`
	OSName        string    `json:"osName"`
	Arch          string    `json:"arch"`
	Kernel        string    `json:"kernel"`
	Uptime        uint64    `json:"uptimeSeconds"`
	BootTime      time.Time `json:"bootTime"`
	Hostname      string    `json:"hostname"`
	Platform      string    `json:"platform"`
	OS            string    `json:"os"`
	Virtualized   bool      `json:"virtualized"`
	Containerized bool      `json:"containerized"`
}

func HostInformation() (HostInfo, error) {
	h, err := host.Info()
	if err != nil {
		return HostInfo{}, err
	}
	bi := HostInfo{
		Host:          HostName(),
		OSName:        h.Platform,
		Arch:          h.KernelArch,
		Kernel:        h.KernelVersion,
		Uptime:        h.Uptime,
		Hostname:      h.Hostname,
		Platform:      h.Platform,
		OS:            h.OS,
		Virtualized:   h.VirtualizationSystem != "",
		Containerized: inContainer(),
	}
	if h.BootTime > 0 {
		bi.BootTime = time.Unix(int64(h.BootTime), 0)
	}
	return bi, nil
}

// inContainer reports whether this process runs inside a container.
func inContainer() bool {
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return true
	}
	data, err := os.ReadFile("/proc/1/cgroup")
	if err != nil {
		return false
	}
	return strings.Contains(string(data), "docker") || strings.Contains(string(data), "containerd") || strings.Contains(string(data), "lxc")
}

// Volume is one mounted filesystem.
type Volume struct {
	Mountpoint string `json:"mountpoint"`
	Device     string `json:"device"`
	FSType     string `json:"fsType"`
	Total      uint64 `json:"total"`
	Used       uint64 `json:"used"`
	Free       uint64 `json:"free"`
}

func Volumes() ([]Volume, error) {
	parts, err := disk.Partitions(false)
	if err != nil {
		return nil, err
	}
	out := make([]Volume, 0, len(parts))
	for _, p := range parts {
		if !strings.HasPrefix(p.Mountpoint, "/") {
			continue
		}
		// Skip pseudo filesystems that carry no meaningful capacity.
		switch p.Fstype {
		case "tmpfs", "devtmpfs", "overlay", "squashfs", "efivarfs", "proc", "sysfs", "cgroup2", "ramfs", "autofs", "mqueue", "debugfs", "tracefs", "configfs", "fusectl", "binfmt_misc", "bpf", "securityfs", "pstore", "hugetlbfs", "devpts", "nsfs", "rpc_pipefs", "selinuxfs", "fuse.snapfuse":
			continue
		}
		v := Volume{Mountpoint: p.Mountpoint, Device: p.Device, FSType: p.Fstype}
		if u, err := disk.Usage(p.Mountpoint); err == nil {
			v.Total = u.Total
			v.Used = u.Used
			v.Free = u.Free
		}
		out = append(out, v)
	}
	return out, nil
}
