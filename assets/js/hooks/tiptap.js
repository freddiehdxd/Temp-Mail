import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Link from "@tiptap/extension-link"
import Image from "@tiptap/extension-image"
import Underline from "@tiptap/extension-underline"
import TextAlign from "@tiptap/extension-text-align"
import { TextStyle } from "@tiptap/extension-text-style"
import { Color } from "@tiptap/extension-color"

function btn(toolbar, { icon, title, action, isActive }) {
  const button = document.createElement("button")
  button.type = "button"
  button.title = title
  button.innerHTML = icon
  button.className = "p-2 rounded-lg transition-colors hover:bg-slate-200 text-slate-700"
  button.addEventListener("click", (e) => {
    e.preventDefault()
    action()
    updateToolbar()
  })
  toolbar.appendChild(button)
  return button

  function updateToolbar() {
    requestAnimationFrame(() => {
      for (const b of toolbar.querySelectorAll("[data-active-check]")) {
        const check = b.getAttribute("data-active-check")
        const active = isActive ? isActive() : false
        b.classList.toggle("bg-indigo-500", active)
        b.classList.toggle("text-white", active)
        b.classList.toggle("text-slate-700", !active)
      }
    })
  }
}

function sep(toolbar) {
  const d = document.createElement("div")
  d.className = "w-px h-6 bg-slate-200 mx-0.5"
  toolbar.appendChild(d)
}

const icons = {
  bold: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/></svg>`,
  italic: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="4" x2="10" y2="4"/><line x1="14" y1="20" x2="5" y2="20"/><line x1="15" y1="4" x2="9" y2="20"/></svg>`,
  underline: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4v6a6 6 0 0 0 12 0V4"/><line x1="4" y1="20" x2="20" y2="20"/></svg>`,
  strike: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 4H9a3 3 0 0 0-2.83 4"/><path d="M14 12a4 4 0 0 1 0 8H6"/><line x1="4" y1="12" x2="20" y2="12"/></svg>`,
  h1: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h8"/><path d="M4 18V6"/><path d="M12 18V6"/><path d="m17 12 3-2v8"/></svg>`,
  h2: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h8"/><path d="M4 18V6"/><path d="M12 18V6"/><path d="M21 18h-4c0-4 4-3 4-6 0-1.5-2-2.5-4-1"/></svg>`,
  h3: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h8"/><path d="M4 18V6"/><path d="M12 18V6"/><path d="M17.5 10.5c1.7-1 3.5 0 3.5 1.5a2 2 0 0 1-2 2"/><path d="M17 17.5c2 1.5 4 .3 4-1.5a2 2 0 0 0-2-2"/></svg>`,
  ul: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>`,
  ol: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="10" y1="6" x2="21" y2="6"/><line x1="10" y1="12" x2="21" y2="12"/><line x1="10" y1="18" x2="21" y2="18"/><path d="M4 6h1v4"/><path d="M4 10h2"/><path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/></svg>`,
  quote: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V21z"/><path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3z"/></svg>`,
  code: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>`,
  link: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>`,
  image: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>`,
  hr: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>`,
  undo: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg>`,
  redo: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>`,
  alignLeft: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="17" y1="10" x2="3" y2="10"/><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="14" x2="3" y2="14"/><line x1="17" y1="18" x2="3" y2="18"/></svg>`,
  alignCenter: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="18" y1="10" x2="6" y2="10"/><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="14" x2="3" y2="14"/><line x1="18" y1="18" x2="6" y2="18"/></svg>`,
  alignRight: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="21" y1="10" x2="7" y2="10"/><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="14" x2="3" y2="14"/><line x1="21" y1="18" x2="7" y2="18"/></svg>`,
}

const TiptapHook = {
  mounted() {
    const textarea = this.el.querySelector("textarea[data-tiptap-target]")
    const editorContainer = this.el.querySelector("[data-tiptap-editor]")
    const toolbar = this.el.querySelector("[data-tiptap-toolbar]")

    if (!textarea || !editorContainer || !toolbar) return

    textarea.style.display = "none"

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

    async function uploadImage(file) {
      const formData = new FormData()
      formData.append("file", file)
      try {
        const res = await fetch("/api/admin/upload", {
          method: "POST",
          headers: csrfToken ? { "x-csrf-token": csrfToken } : {},
          body: formData,
        })
        const data = await res.json()
        if (data.success && data.url) return data.url
        console.error("Upload failed:", data.error)
        return null
      } catch (err) {
        console.error("Upload error:", err)
        return null
      }
    }

    const editor = new Editor({
      element: editorContainer,
      extensions: [
        StarterKit.configure({ heading: { levels: [1, 2, 3] } }),
        Link.configure({ openOnClick: false, HTMLAttributes: { class: "text-indigo-500 underline" } }),
        Image.configure({ HTMLAttributes: { class: "max-w-full rounded-lg" } }),
        Underline,
        TextAlign.configure({ types: ["heading", "paragraph"] }),
        TextStyle,
        Color,
      ],
      content: textarea.value || "",
      editorProps: {
        attributes: {
          class: "prose prose-sm max-w-none focus:outline-none min-h-[300px] px-4 py-3",
        },
        handlePaste: (view, event) => {
          const items = event.clipboardData?.items
          if (!items) return false
          for (let i = 0; i < items.length; i++) {
            if (items[i].type.startsWith("image/")) {
              event.preventDefault()
              const file = items[i].getAsFile()
              if (file) {
                uploadImage(file).then((url) => {
                  if (url) editor.chain().focus().setImage({ src: url }).run()
                })
              }
              return true
            }
          }
          return false
        },
        handleDrop: (view, event, _slice, moved) => {
          if (moved || !event.dataTransfer?.files?.length) return false
          const file = Array.from(event.dataTransfer.files).find((f) => f.type.startsWith("image/"))
          if (!file) return false
          event.preventDefault()
          const coords = view.posAtCoords({ left: event.clientX, top: event.clientY })
          uploadImage(file).then((url) => {
            if (!url) return
            if (coords) {
              editor.chain().focus().setTextSelection(coords.pos).setImage({ src: url }).run()
            } else {
              editor.chain().focus().setImage({ src: url }).run()
            }
          })
          return true
        },
      },
      onUpdate: ({ editor: ed }) => {
        textarea.value = ed.getHTML()
        textarea.dispatchEvent(new Event("input", { bubbles: true }))
      },
    })

    this.editor = editor

    const update = () => {
      toolbar.querySelectorAll("button[data-check]").forEach((b) => {
        const check = b.dataset.check
        let active = false
        if (check === "bold") active = editor.isActive("bold")
        else if (check === "italic") active = editor.isActive("italic")
        else if (check === "underline") active = editor.isActive("underline")
        else if (check === "strike") active = editor.isActive("strike")
        else if (check === "h1") active = editor.isActive("heading", { level: 1 })
        else if (check === "h2") active = editor.isActive("heading", { level: 2 })
        else if (check === "h3") active = editor.isActive("heading", { level: 3 })
        else if (check === "bulletList") active = editor.isActive("bulletList")
        else if (check === "orderedList") active = editor.isActive("orderedList")
        else if (check === "blockquote") active = editor.isActive("blockquote")
        else if (check === "codeBlock") active = editor.isActive("codeBlock")
        else if (check === "link") active = editor.isActive("link")
        else if (check === "alignLeft") active = editor.isActive({ textAlign: "left" })
        else if (check === "alignCenter") active = editor.isActive({ textAlign: "center" })
        else if (check === "alignRight") active = editor.isActive({ textAlign: "right" })
        b.classList.toggle("bg-indigo-500", active)
        b.classList.toggle("text-white", active)
        b.classList.toggle("hover:bg-slate-200", !active)
      })
    }

    editor.on("selectionUpdate", update)
    editor.on("update", update)

    toolbar.addEventListener("click", (e) => {
      const button = e.target.closest("button[data-cmd]")
      if (!button) return
      e.preventDefault()

      const cmd = button.dataset.cmd
      if (cmd === "bold") editor.chain().focus().toggleBold().run()
      else if (cmd === "italic") editor.chain().focus().toggleItalic().run()
      else if (cmd === "underline") editor.chain().focus().toggleUnderline().run()
      else if (cmd === "strike") editor.chain().focus().toggleStrike().run()
      else if (cmd === "h1") editor.chain().focus().toggleHeading({ level: 1 }).run()
      else if (cmd === "h2") editor.chain().focus().toggleHeading({ level: 2 }).run()
      else if (cmd === "h3") editor.chain().focus().toggleHeading({ level: 3 }).run()
      else if (cmd === "bulletList") editor.chain().focus().toggleBulletList().run()
      else if (cmd === "orderedList") editor.chain().focus().toggleOrderedList().run()
      else if (cmd === "blockquote") editor.chain().focus().toggleBlockquote().run()
      else if (cmd === "codeBlock") editor.chain().focus().toggleCodeBlock().run()
      else if (cmd === "hr") editor.chain().focus().setHorizontalRule().run()
      else if (cmd === "undo") editor.chain().focus().undo().run()
      else if (cmd === "redo") editor.chain().focus().redo().run()
      else if (cmd === "alignLeft") editor.chain().focus().setTextAlign("left").run()
      else if (cmd === "alignCenter") editor.chain().focus().setTextAlign("center").run()
      else if (cmd === "alignRight") editor.chain().focus().setTextAlign("right").run()
      else if (cmd === "link") {
        const url = window.prompt("URL", editor.getAttributes("link").href || "")
        if (url === null) return
        if (url === "") { editor.chain().focus().unsetLink().run(); return }
        editor.chain().focus().extendMarkRange("link").setLink({ href: url }).run()
      }
      else if (cmd === "image") {
        const choice = window.confirm("OK to upload a file, Cancel to enter a URL")
        if (choice) {
          const input = document.createElement("input")
          input.type = "file"
          input.accept = "image/jpeg,image/png,image/gif,image/webp"
          input.onchange = async (ev) => {
            const file = ev.target.files?.[0]
            if (!file) return
            const url = await uploadImage(file)
            if (url) editor.chain().focus().setImage({ src: url }).run()
          }
          input.click()
        } else {
          const url = window.prompt("Image URL")
          if (url) editor.chain().focus().setImage({ src: url }).run()
        }
      }

      requestAnimationFrame(update)
    })
  },

  updated() {
    if (!this.editor) return
    const textarea = this.el.querySelector("textarea[data-tiptap-target]")
    if (textarea && textarea.value !== this.editor.getHTML()) {
      this.editor.commands.setContent(textarea.value || "")
    }
  },

  destroyed() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  },
}

export default TiptapHook
