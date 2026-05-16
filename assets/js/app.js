// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

import ChartHook from "./hooks/chart"
import TiptapHook from "./hooks/tiptap"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let Hooks = {}
Hooks.ChartHook = ChartHook
Hooks.TiptapHook = TiptapHook

Hooks.Clipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const value = this.el.dataset.copy
      if (value && navigator.clipboard) navigator.clipboard.writeText(value)
    })
  }
}

Hooks.TempMailPersist = {
  mounted() {
    const stored = localStorage.getItem("tempmail_address")
    this.pushEvent("restore_or_generate", { address: stored || "" })

    this.handleEvent("tempmail_created", ({ address }) => {
      if (address) localStorage.setItem("tempmail_address", address)
    })
  }
}

const detailsState = new Map()

Hooks.PersistDetails = {
  mounted() {
    this.key = this.el.dataset.menuId || this.el.id
    if (detailsState.get(this.key)) this.el.open = true

    this.el.addEventListener("toggle", () => {
      detailsState.set(this.key, this.el.open)
    })
  },
  updated() {
    if (detailsState.get(this.key)) this.el.open = true
  },
  destroyed() {
    detailsState.set(this.key, this.el.open)
  }
}

function syncHeader() {
  const header = document.querySelector("[data-site-header]")
  if (!header) return

  const scrolled = window.scrollY > 20
  header.classList.toggle("py-4", !scrolled)
  header.classList.toggle("py-2", scrolled)
  header.classList.toggle("bg-transparent", !scrolled)
  header.classList.toggle("bg-white/80", scrolled)
  header.classList.toggle("backdrop-blur-xl", scrolled)
  header.classList.toggle("shadow-lg", scrolled)
  header.classList.toggle("shadow-black/5", scrolled)
}

window.addEventListener("scroll", syncHeader, { passive: true })
window.addEventListener("phx:page-loading-stop", syncHeader)
window.addEventListener("DOMContentLoaded", syncHeader)

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
