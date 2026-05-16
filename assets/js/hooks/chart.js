import { Chart, registerables } from "chart.js"
Chart.register(...registerables)

function buildGradient(ctx, canvas, color) {
  const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height)
  gradient.addColorStop(0, color.from)
  gradient.addColorStop(1, color.to)
  return gradient
}

const ChartHook = {
  mounted() {
    const config = JSON.parse(this.el.dataset.config)
    const ctx = this.el.getContext("2d")

    if (config.data && config.data.datasets) {
      config.data.datasets.forEach((ds) => {
        if (ds._gradient) {
          ds.backgroundColor = buildGradient(ctx, this.el, ds._gradient)
          delete ds._gradient
        }
      })
    }

    this.chart = new Chart(ctx, config)

    this.handleEvent(`chart-update-${this.el.id}`, (payload) => {
      this.chart.data.labels = payload.labels
      payload.datasets.forEach((incoming, i) => {
        if (this.chart.data.datasets[i]) {
          this.chart.data.datasets[i].data = incoming.data
        }
      })
      this.chart.update("none")
    })
  },

  updated() {
    const config = JSON.parse(this.el.dataset.config)
    const ctx = this.el.getContext("2d")

    this.chart.data.labels = config.data.labels
    config.data.datasets.forEach((ds, i) => {
      if (ds._gradient) {
        ds.backgroundColor = buildGradient(ctx, this.el, ds._gradient)
        delete ds._gradient
      }
      if (this.chart.data.datasets[i]) {
        Object.assign(this.chart.data.datasets[i], ds)
      }
    })
    this.chart.update()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },
}

export default ChartHook
