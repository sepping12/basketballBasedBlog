// Capitolo 9 — Prova end-to-end dei template JavaScript (.js.erb) dei commenti, in un DOM vero.
//
// Cosa fa: apre la pagina di un articolo in jsdom (un browser simulato), poi ripete ciò che farebbe rails-ujs:
// richieste XHR con gli header giusti, e valuta il JavaScript ricevuto. Controlla che la pagina cambi davvero:
// form che compare, commento aggiunto/rifiutato/eliminato, titolo aggiornato, messaggi, niente XSS.
//
// Come lanciarla (jsdom NON è una dipendenza del progetto: si installa in una cartella a parte):
//   mkdir /tmp/jsd && cd /tmp/jsd && npm install jsdom@22
//   (nel progetto)  bin/rails server -p 3056          # in un altro terminale
//   (in /tmp/jsd)   NODE_PATH=/tmp/jsd/node_modules node /percorso/del/progetto/capitoli/capitolo9_prova_ajax.js 5
// L'argomento (5) è l'id di un articolo PUBBLICATO il cui autore è mary@example.com (password: guessit).
// Lascia dei commenti "JSDOM…" nel database di sviluppo: quelli di prova vengono eliminati dalla prova stessa,
// quello rifiutato non viene salvato. Se la prova si interrompe: Comment.where("name LIKE ?", "JSDOM%").destroy_all
// Prova end-to-end dei template .js.erb: un DOM vero (jsdom) + il server Rails in funzione.
// Simula quello che fa rails-ujs nel browser (richieste XHR con gli header giusti, poi valuta il JavaScript ricevuto).
const { JSDOM } = require("jsdom");
const BASE = "http://localhost:3056";
let passati = 0, falliti = 0;
function ok(cond, msg) { if (cond) { passati++; console.log("  ✓ " + msg); } else { falliti++; console.log("  ✗ FALLITO: " + msg); } }

class Browser {
  constructor() { this.cookies = {}; }
  cookieHeader() { return Object.entries(this.cookies).map(([k, v]) => `${k}=${v}`).join("; "); }
  async req(path, { method = "GET", headers = {}, body } = {}) {
    const res = await fetch(BASE + path, { method, headers: { Cookie: this.cookieHeader(), ...headers }, body, redirect: "manual" });
    for (const c of res.headers.getSetCookie ? res.headers.getSetCookie() : []) { const [kv] = c.split(";"); const i = kv.indexOf("="); this.cookies[kv.slice(0, i)] = kv.slice(i + 1); }
    return { status: res.status, text: await res.text(), type: res.headers.get("content-type") || "" };
  }
  async pagina(path) {
    const r = await this.req(path, { headers: { Accept: "text/html" } });
    const dom = new JSDOM(r.text, { url: BASE + path, runScripts: "outside-only" });   // niente script della pagina: li valutiamo noi
    const token = dom.window.document.querySelector("meta[name=csrf-token]").content;
    return { dom, window: dom.window, doc: dom.window.document, token };
  }
  // Come rails-ujs: richiesta XHR che accetta JavaScript; la risposta viene VALUTATA (anche con status 4xx).
  async ajax(pag, path, { method = "GET", form } = {}) {
    const headers = { Accept: "text/javascript, application/javascript, */*; q=0.01", "X-Requested-With": "XMLHttpRequest", "X-CSRF-Token": pag.token };
    let body;
    if (form) { body = new URLSearchParams(form).toString(); headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"; }
    const r = await this.req(path, { method, headers, body });
    if (/javascript/.test(r.type)) pag.window.eval(r.text);
    return r;
  }
}

(async () => {
  const ARTICOLO = process.argv[2];
  const visitatore = new Browser();
  const pag = await visitatore.pagina(`/articles/${ARTICOLO}`);
  const { doc } = pag;
  const q = (s) => doc.querySelector(s);
  const qa = (s) => doc.querySelectorAll(s);

  console.log("1) Pagina dell'articolo, da visitatore");
  const commentiPrima = qa("#commenti-lista .comment").length;
  ok(q("#form-commento form") === null, "il form dei commenti NON è nella pagina");
  ok(q("#new_comment_link") && q("#new_comment_link").getAttribute("data-remote") === "true", "c'è il link 'Scrivi un commento' con data-remote");
  ok(q("#new_comment_link").style.display !== "none", "il link è visibile");

  console.log("2) Click su 'Scrivi un commento' → GET new.js (Ajax)");
  let r = await visitatore.ajax(pag, q("#new_comment_link").getAttribute("href"));
  ok(r.status === 200 && /javascript/.test(r.type), `risposta ${r.status} ${r.type}`);
  ok(q("#form-commento form") !== null, "il form è comparso nella pagina");
  ok(q("#form-commento form").getAttribute("data-remote") === "true", "il form invierà via Ajax (data-remote)");
  ok(q("#new_comment_link").style.display === "none", "il link è stato nascosto");
  ok(q("#form-commento").classList.contains("fade-in"), "il contenitore ha la classe fade-in (animazione CSS)");
  ok(doc.activeElement && doc.activeElement.name === "comment[name]", "il primo campo ha il focus");

  console.log("3) Invio di un commento NON valido (nome vuoto) → 422 + form con gli errori");
  const form = () => q("#form-commento form");
  let campi = { "comment[name]": "", "comment[email]": "jsdom@example.com", "comment[body]": "Testo da non perdere \"con virgolette\" e </script> dentro" };
  r = await visitatore.ajax(pag, form().getAttribute("action"), { method: "POST", form: { authenticity_token: pag.token, ...campi } });
  ok(r.status === 422, `status ${r.status}`);
  ok(q("#form-commento #error_explanation") !== null, "nel form compare il blocco degli errori");
  ok(/Nome è obbligatorio/.test(q("#error_explanation").textContent), "messaggio: 'Nome è obbligatorio'");
  ok(q("#form-commento textarea").value.includes('</script> dentro'), "il testo già scritto è rimasto nel campo");
  ok(qa("#commenti-lista .comment").length === commentiPrima, "nessun commento aggiunto");

  console.log("4) Invio di un commento valido → create.js");
  campi = { "comment[name]": "JSDOM <b>Tester</b>", "comment[email]": "jsdom@example.com", "comment[body]": "Primo paragrafo\n\nSecondo con \"virgolette\" e 'apici' e </script>" };
  r = await visitatore.ajax(pag, form().getAttribute("action"), { method: "POST", form: { authenticity_token: pag.token, ...campi } });
  ok(r.status === 200, `status ${r.status}`);
  ok(qa("#commenti-lista .comment").length === commentiPrima + 1, "un commento in più nella lista, senza ricaricare la pagina");
  const nuovo = qa("#commenti-lista .comment")[qa("#commenti-lista .comment").length - 1];
  ok(nuovo.querySelector("strong").textContent === "JSDOM <b>Tester</b>", "il nome è mostrato come TESTO (nessun <b> interpretato: niente XSS)");
  ok(nuovo.querySelector("strong b") === null, "nessun elemento <b> creato dentro il nome");
  ok(nuovo.querySelectorAll("p").length === 2, "il testo ha due paragrafi (simple_format)");
  ok(nuovo.querySelector("script") === null, "nessun <script> creato: il </script> scritto nel testo non rompe né esegue nulla");
  ok(nuovo.textContent.includes("Secondo con \"virgolette\" e 'apici'"), "virgolette e apici del testo sono arrivati intatti (escape_javascript)");
  ok(q("#commenti-titolo").textContent === `${commentiPrima + 1} ${commentiPrima + 1 === 1 ? "commento" : "commenti"}`, `il titolo si aggiorna: "${q("#commenti-titolo").textContent}"`);
  ok(q("#commenti-vuoto").hidden === true, "il messaggio 'nessun commento' è nascosto");
  ok(q("#form-commento form") && q("#form-commento textarea").value.trim() === "", "il form è stato sostituito con uno nuovo e vuoto");
  ok(q("#form-commento #error_explanation") === null, "...senza errori residui");
  ok(doc.body.querySelector(".toast") && /Grazie/.test(doc.body.querySelector(".toast").textContent), "compare il messaggio 'Grazie per il commento!'");
  ok(nuovo.querySelector(".comment__delete") === null, "il visitatore non vede il link Elimina sul suo commento");

  console.log("5) L'autore dell'articolo (mary) elimina un commento → destroy.js");
  const autore = new Browser();
  let lp = await autore.pagina("/login");
  r = await autore.req("/session", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": lp.token }, body: new URLSearchParams({ authenticity_token: lp.token, email: "mary@example.com", password: "guessit" }).toString() });
  ok(r.status === 302, `login: ${r.status}`);
  const pa = await autore.pagina(`/articles/${ARTICOLO}`);
  const cmt = [...pa.doc.querySelectorAll("#commenti-lista .comment")].find((c) => c.textContent.includes("JSDOM"));
  ok(cmt !== undefined, "da autore la pagina mostra il commento di prova");
  ok(cmt.querySelector(".comment__email") && cmt.querySelector(".comment__email").textContent === "jsdom@example.com", "l'autore vede l'email del commentatore");
  const link = cmt.querySelector("a.comment__delete");
  ok(link.getAttribute("data-remote") === "true" && link.getAttribute("data-method") === "delete", "il link Elimina è Ajax (data-remote, data-method=delete)");
  const prima = pa.doc.querySelectorAll("#commenti-lista .comment").length;
  r = await autore.ajax(pa, link.getAttribute("href"), { method: "DELETE" });
  ok(r.status === 200, `status ${r.status}`);
  ok(pa.doc.querySelector("#" + cmt.id) === null, "il commento è sparito dalla pagina senza ricaricarla");
  ok(pa.doc.querySelectorAll("#commenti-lista .comment").length === prima - 1, "un commento in meno");
  ok(pa.doc.querySelector("#commenti-titolo").textContent.startsWith(String(prima - 1)), `il titolo si aggiorna: "${pa.doc.querySelector("#commenti-titolo").textContent}"`);
  const avvisi = [...pa.doc.body.querySelectorAll(".toast")];
  ok(/eliminato/.test(avvisi[avvisi.length - 1].textContent), "compare il messaggio 'Commento eliminato.'");

  console.log(`\nRISULTATO: ${passati} controlli riusciti, ${falliti} falliti`);
  process.exit(falliti ? 1 : 0);
})().catch((e) => { console.error("ERRORE:", e); process.exit(2); });
