package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	versionCollector "github.com/prometheus/client_golang/prometheus/collectors/version"
)

var registry = prometheus.NewRegistry()

func DefaultRegistry() prometheus.Registerer {
	return registry
}

func init() {
	registry.MustRegister(
		versionCollector.NewCollector("clusterpedia_kube_state_metrics"),
		collectors.NewGoCollector(),
		collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}),
	)
}
