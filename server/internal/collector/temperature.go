package collector

import (
	"github.com/shirou/gopsutil/v4/sensors"
)

// Temperature is one reading from a hardware sensor.
type Temperature struct {
	Name  string  `json:"name"`
	Value float64 `json:"value"`
	High  float64 `json:"high"`
	Crit  float64 `json:"critical"`
}

// Temperatures returns every readable temperature sensor.
func Temperatures() []Temperature {
	list, err := sensors.SensorsTemperatures()
	if err != nil {
		return []Temperature{}
	}
	out := make([]Temperature, 0, len(list))
	for _, s := range list {
		out = append(out, Temperature{
			Name:  s.SensorKey,
			Value: s.Temperature,
			High:  s.High,
			Crit:  s.Critical,
		})
	}
	return out
}
