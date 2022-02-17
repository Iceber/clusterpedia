package v1beta1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// +k8s:conversion-gen:explicit-from=net/url.Values
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type ListOptions struct {
	metav1.ListOptions `json:",inline"`

	// +optional
	Names string `json:"names,omitempty"`

	// +optional
	Owner string `json:"owner,omitempty"`

	// +optional
	ClusterNames string `json:"clusters,omitempty"`

	// +optional
	Namespaces string `json:"namespaces,omitempty"`

	// +optional
	OrderBy string `json:"orderby,omitempty"`

	// +optional
	WithContinue *bool `json:"withContinue,omitempty"`

	// +optional
	WithRemainingCount *bool `json:"withRemainingCount,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type Resources struct {
	metav1.TypeMeta `json:",inline"`
}

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type CollectionResource struct {
	metav1.TypeMeta `json:",inline"`

	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// +required
	ResourceTypes []CollectionResourceType `json:"resourceTypes"`

	// +optional
	Items []runtime.RawExtension `json:"items,omitempty"`
}

type CollectionResourceType struct {
	Group string `json:"group"`

	Version string `json:"version"`

	// +optional
	Kind string `json:"kind,omitempty"`

	Resource string `json:"resource"`
}

// +kubebuilder:object:root=true
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type CollectionResourceList struct {
	metav1.TypeMeta `json:",inline"`

	// +optional
	metav1.ListMeta `json:"metadata,omitempty"`

	Items []CollectionResource `json:"items"`
}
