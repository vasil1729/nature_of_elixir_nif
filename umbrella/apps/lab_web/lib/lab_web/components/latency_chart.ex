defmodule LabWeb.Components.LatencyChart do
  @moduledoc """
  Renders a latency chart using chart.js via a phx-hook.

  The chart shows p50/p99/max over time. Data points are pushed via
  LiveView `push_event/3` to the client-side hook.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :data, :list, default: []

  def latency_chart(assigns) do
    ~H"""
    <div class="chart-container">
      <canvas id={@id} phx-hook="LatencyChart" data-points={Jason.encode!(Enum.take(@data, -100))}>
      </canvas>
    </div>
    <script>
      // Chart.js hook for latency updates
      window.LatencyChart = {
        mounted() {
          const canvas = this.el;
          const ctx = canvas.getContext('2d');
          const points = JSON.parse(canvas.dataset.points || '[]');
          this.chart = new Chart(ctx, {
            type: 'line',
            data: {
              labels: points.map((_, i) => i),
              datasets: [
                { label: 'p50', data: points.map(p => p.p50_us / 1000), borderColor: '#4caf50', fill: false },
                { label: 'p99', data: points.map(p => p.p99_us / 1000), borderColor: '#ff9800', fill: false },
                { label: 'max', data: points.map(p => p.max_us / 1000), borderColor: '#f44336', fill: false }
              ]
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
              scales: { y: { title: { display: true, text: 'ms' } } }
            }
          });
        },
        updated() {
          if (this.chart) {
            const points = JSON.parse(this.el.dataset.points || '[]');
            this.chart.data.labels = points.map((_, i) => i);
            this.chart.data.datasets[0].data = points.map(p => (p.p50_us || 0) / 1000);
            this.chart.data.datasets[1].data = points.map(p => (p.p99_us || 0) / 1000);
            this.chart.data.datasets[2].data = points.map(p => (p.max_us || 0) / 1000);
            this.chart.update('none');
          }
        }
      };
    </script>
    """
  end
end
