package collector

import (
	"context"
	"encoding/json"
	"os/exec"
	"sort"
	"strings"
	"time"
)

// Service is one container or host service shown on the dashboard.
type Service struct {
	ID        string     `json:"id"`
	Name      string     `json:"name"`
	Image     string     `json:"image"`
	State     string     `json:"state"`
	Status    string     `json:"status"`
	Ports     string     `json:"ports"`
	StartedAt *time.Time `json:"startedAt,omitempty"`
	UpdatedAt time.Time  `json:"updatedAt"`
}

type dockerContainer struct {
	ID      string `json:"ID"`
	Names   string `json:"Names"`
	Image   string `json:"Image"`
	State   string `json:"State"`
	Status  string `json:"Status"`
	Ports   string `json:"Ports"`
	Created int64  `json:"Created"`
}

// ListServices enumerates docker containers on the local machine.
func ListServices() ([]Service, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	out, err := exec.CommandContext(ctx, "docker", "ps", "-a", "--format", "{{json .}}").Output()
	if err != nil {
		return nil, err
	}

	rows := strings.Split(strings.TrimSpace(string(out)), "\n")
	services := make([]Service, 0, len(rows))
	for _, row := range rows {
		row = strings.TrimSpace(row)
		if row == "" {
			continue
		}
		var c dockerContainer
		if err := json.Unmarshal([]byte(row), &c); err != nil {
			continue
		}
		name := c.Names
		if i := strings.Index(name, ","); i >= 0 {
			name = name[:i]
		}
		s := Service{
			ID:        c.ID,
			Name:      name,
			Image:     c.Image,
			State:     c.State,
			Status:    c.Status,
			Ports:     c.Ports,
			UpdatedAt: time.Now(),
		}
		if t, ok := startedAt(ctx, c.ID); ok {
			s.StartedAt = &t
		}
		services = append(services, s)
	}
	sort.Slice(services, func(i, j int) bool { return services[i].Name < services[j].Name })
	return services, nil
}

func startedAt(ctx context.Context, id string) (time.Time, bool) {
	out, err := exec.CommandContext(ctx, "docker", "inspect", "--format", "{{.State.StartedAt}}", id).Output()
	if err != nil {
		return time.Time{}, false
	}
	s := strings.TrimSpace(string(out))
	if s == "" || strings.HasPrefix(s, "0001-01-01") {
		return time.Time{}, false
	}
	t, err := time.Parse(time.RFC3339Nano, s)
	if err != nil {
		return time.Time{}, false
	}
	return t, true
}

// ContainerAction performs a lifecycle action on a container.
func ContainerAction(id, action string) (string, error) {
	switch action {
	case "start", "stop", "restart", "pause", "unpause", "kill":
	default:
		return "", errInvalidAction
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "docker", action, id).CombinedOutput()
	if err != nil {
		return string(out), err
	}
	return strings.TrimSpace(string(out)), nil
}

type errString string

func (e errString) Error() string { return string(e) }

const errInvalidAction = errString("invalid action")
