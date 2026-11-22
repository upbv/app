package collector

import (
	"os"
	"strconv"
	"strings"

	"github.com/shirou/gopsutil/v4/sensors"
)

// avgLoad returns the 1-minute load average.
func avgLoad() (float64, error) {
	b, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return 0, err
	}
	fields := strings.Fields(string(b))
	if len(fields) == 0 {
		return 0, strconv.ErrSyntax
	}
	return strconv.ParseFloat(fields[0], 64)
}

// cpuTemp returns the highest core temperature in celsius, if any sensor is readable.
func cpuTemp() (float64, bool) {
	list, err := sensors.SensorsTemperatures()
	if err != nil || len(list) == 0 {
		return 0, false
	}
	highest := list[0].Temperature
	for _, s := range list[1:] {
		if s.Temperature > highest {
			highest = s.Temperature
		}
	}
	return highest, true
}

// Fan describes one cooling fan reported by the hardware.
type Fan struct {
	Name      string  `json:"name"`
	SpeedRPM  float64 `json:"speedRpm"`
	TargetRPM float64 `json:"targetRpm"`
}

// Fans reads cooling fan RPM from the hwmon interface where exposed.
func Fans() []Fan {
	out := make([]Fan, 0)
	base := "/sys/class/hwmon"
	entries, err := os.ReadDir(base)
	if err != nil {
		return out
	}
	for _, e := range entries {
		dir := base + "/" + e.Name()
		label, _ := os.ReadFile(dir + "/name")
		name := strings.TrimSpace(string(label))
		if name == "" {
			name = e.Name()
		}
		for i := 1; i <= 8; i++ {
			speedPath := dir + "/fan" + strconv.Itoa(i) + "_input"
			b, err := os.ReadFile(speedPath)
			if err != nil {
				continue
			}
			rpm, err := strconv.ParseFloat(strings.TrimSpace(string(b)), 64)
			if err != nil {
				continue
			}
			out = append(out, Fan{Name: name + "_fan" + strconv.Itoa(i), SpeedRPM: rpm})
		}
	}
	return out
}
