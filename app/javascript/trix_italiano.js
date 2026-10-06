// Testi italiani per l'editor Trix (suggerimenti della barra degli strumenti e messaggi).
// Importato da packs/application.js dopo require("trix").
import Trix from "trix"

Trix.config.lang = Object.assign(Trix.config.lang, {
  attachFiles: "Allega file",
  bold: "Grassetto",
  bullets: "Elenco puntato",
  byte: "Byte",
  bytes: "Byte",
  captionPlaceholder: "Aggiungi una didascalia…",
  code: "Codice",
  heading1: "Titolo",
  indent: "Aumenta rientro",
  italic: "Corsivo",
  link: "Link",
  numbers: "Elenco numerato",
  outdent: "Riduci rientro",
  quote: "Citazione",
  redo: "Ripeti",
  remove: "Rimuovi",
  strike: "Barrato",
  undo: "Annulla",
  unlink: "Rimuovi link",
  url: "Indirizzo (URL)",
  urlPlaceholder: "Incolla un indirizzo…",
  GB: "GB", KB: "KB", MB: "MB", PB: "PB", TB: "TB"
})
