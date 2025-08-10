import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="bulk-progress"
// Iterates over entry ids, POSTing update_one for each and showing progress per item
export default class extends Controller {
  static targets = ["list"];
  static values = {
    entryIds: Array,
    updateUrl: String,
  };

  connect() {
    this._started = false;
  }

  start() {
    if (this._started) return;
    this._started = true;
    this._processNext(0);
  }

  _processNext(index) {
    if (index >= this.entryIdsValue.length) return;

    const entryId = this.entryIdsValue[index];
    const li = document.createElement("li");
    li.className = "text-sm flex items-center gap-2";
    li.innerHTML = `<span class='text-secondary'>Entry ${index + 1}/${
      this.entryIdsValue.length
    }</span> <span data-status>Starting…</span>`;
    this.listTarget.appendChild(li);

    const formData = new FormData(document.getElementById("bulk-edit-form"));
    const payload = new URLSearchParams();
    payload.append("entry_id", entryId);
    for (const [key, value] of formData.entries()) {
      payload.append(key, value);
    }

    fetch(this.updateUrlValue, {
      method: "POST",
      headers: { "Accept": "application/json" },
      body: payload,
    })
      .then((r) => r.json())
      .then((json) => {
        if (json.ok) {
          li.querySelector("[data-status]").innerText = "✓ Updated";
          this._processNext(index + 1);
        } else {
          li.querySelector("[data-status]").innerText = `✕ Failed: ${json.error}`;
        }
      })
      .catch((e) => {
        li.querySelector("[data-status]").innerText = `✕ Failed: ${e}`;
      });
  }
}
