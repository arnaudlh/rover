package azure

import (
	"context"
	"testing"
)

func TestStorageAccountFilter_matches(t *testing.T) {
	tests := []struct {
		name   string
		filter StorageAccountFilter
		tags   map[string]*string
		want   bool
	}{
		{
			name: "matches caf tags",
			filter: StorageAccountFilter{
				Level:       "level0",
				Environment: "dev",
			},
			tags: map[string]*string{
				"caf_tfstate":     stringPtr("level0"),
				"caf_environment": stringPtr("dev"),
			},
			want: true,
		},
		{
			name: "matches legacy tags",
			filter: StorageAccountFilter{
				Level:       "level0",
				Environment: "dev",
			},
			tags: map[string]*string{
				"tfstate":     stringPtr("level0"),
				"environment": stringPtr("dev"),
			},
			want: true,
		},
		{
			name: "no match",
			filter: StorageAccountFilter{
				Level:       "level0",
				Environment: "dev",
			},
			tags: map[string]*string{
				"tfstate":     stringPtr("level1"),
				"environment": stringPtr("prod"),
			},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.filter.matches(tt.tags); got != tt.want {
				t.Errorf("StorageAccountFilter.matches() = %v, want %v", got, tt.want)
			}
		})
	}
}

func stringPtr(s string) *string {
	return &s
}
