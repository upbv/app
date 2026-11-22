package collector

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Disk describes one physical block device.
type Disk struct {
	Name        string   `json:"name"`
	Model       string   `json:"model"`
	Serial      string   `json:"serial"`
	Size        uint64   `json:"size"`
	Temperature *float64 `json:"temperature,omitempty"`
	Health      string   `json:"health"`
	SmartOK     bool     `json:"smartOk"`
	Mountpoint  string   `json:"mountpoint"`
	Rotational  bool     `json:"rotational"`
}

// Disks enumerates physical block devices visible on the machine.
func Disks() []Disk {
	out := make([]Disk, 0)
	entries, err := os.ReadDir("/sys/block")
	if err != nil {
		return out
	}
	for _, e := range entries {
		name := e.Name()
		if strings.HasPrefix(name, "loop") || strings.HasPrefix(name, "ram") || strings.HasPrefix(name, "dm-") {
			continue
		}
		d := Disk{Name: name, Health: "unknown"}
		if v, err := readInt(filepath.Join("/sys/block", name, "size")); err == nil {
			d.Size = uint64(v) * 512
		}
		if v, err := os.ReadFile(filepath.Join("/sys/block", name, "device", "model")); err == nil {
			d.Model = strings.TrimSpace(string(v))
		}
		if v, err := os.ReadFile(filepath.Join("/sys/block", name, "device", "serial")); err == nil {
			d.Serial = strings.TrimSpace(string(v))
		}
		if v, err := os.ReadFile(filepath.Join("/sys/block", name, "queue", "rotational")); err == nil {
			d.Rotational = strings.TrimSpace(string(v)) == "1"
		}
		if mp, ok := mountpointOf(name); ok {
			d.Mountpoint = mp
		}
		out = append(out, d)
	}

	// smartctl gives temperature and health, but only when it is installed.
	if _, err := exec.LookPath("smartctl"); err == nil {
		for i := range out {
			if t, health, ok := smartctl(out[i].Name); ok {
				if t > 0 {
					tv := t
					out[i].Temperature = &tv
				}
				out[i].Health = health
				out[i].SmartOK = health == "PASSED"
			}
		}
	}
	return out
}

// smartctl queries a device and returns its temperature and health verdict.
func smartctl(device string) (float64, string, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "smartctl", "-A", "-H", "/dev/"+device)
	out, err := cmd.CombinedOutput()
	if err != nil && len(out) == 0 {
		return 0, "", false
	}
	text := string(out)

	temp := 0.0
	health := ""
	for _, line := range strings.Split(text, "\n") {
		lower := strings.ToLower(line)
		if strings.Contains(lower, "temperature") || strings.Contains(lower, "air temperature") {
			if v, ok := firstFloatAfterColon(line); ok {
				temp = v
			}
		}
		if strings.Contains(lower, "smart overall-health") || strings.Contains(lower, "overall-health") {
			fields := strings.Fields(strings.TrimSpace(line))
			if len(fields) > 0 {
				health = strings.TrimPrefix(fields[len(fields)-1], "[")
				health = strings.TrimSuffix(health, "]")
				if i := strings.Index(health, "]"); i >= 0 {
					health = health[:i]
				}
			}
		}
	}
	if temp == 0 && health == "" {
		return 0, "", false
	}
	return temp, health, true
}

func firstFloatAfterColon(line string) (float64, bool) {
	idx := strings.Index(line, ":")
	if idx < 0 {
		return 0, false
	}
	rest := line[idx+1:]
	for _, f := range strings.Fields(rest) {
		if v, err := strconv.ParseFloat(strings.TrimSpace(f), 64); err == nil {
			return v, true
		}
	}
	return 0, false
}

// mountpointOf finds where a block device is mounted, if anywhere.
func mountpointOf(device string) (string, bool) {
	data, err := os.ReadFile("/proc/self/mounts")
	if err != nil {
		return "", false
	}
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		src := fields[0]
		if filepath.Base(src) == device {
			return fields[1], true
		}
	}
	return "", false
}

func readInt(path string) (int64, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	return strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
}
