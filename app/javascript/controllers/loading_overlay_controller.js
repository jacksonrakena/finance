import { Controller } from "@hotwired/stimulus";

// Adds a simple loading overlay to its container target when a Turbo request starts,
// and removes it when the request finishes.
// Usage:
// <div data-controller="loading-overlay" data-loading-overlay-target="container">
//   ... your content ...
//   <form data-controller="auto-submit-form loading-overlay"> ... </form>
// </div>
export default class extends Controller {
  static targets = ["container"];

  connect() {
    this._onStart = this._onStart.bind(this);
    this._onEnd = this._onEnd.bind(this);
    addEventListener("turbo:before-fetch-request", this._onStart);
    addEventListener("turbo:before-fetch-response", this._onEnd);
  }

  disconnect() {
    removeEventListener("turbo:before-fetch-request", this._onStart);
    removeEventListener("turbo:before-fetch-response", this._onEnd);
  }

  _onStart() {
    this._ensureOverlay();
    this.overlayTarget.classList.remove("hidden");
    this.containerTarget.classList.add("opacity-50", "pointer-events-none");
  }

  _onEnd() {
    if (!this.hasOverlayTarget) return;
    this.overlayTarget.classList.add("hidden");
    this.containerTarget.classList.remove("opacity-50", "pointer-events-none");
  }

  _ensureOverlay() {
    if (this.hasOverlayTarget) return;
    const overlay = document.createElement("div");
    overlay.dataset.loadingOverlayTarget = "overlay";
    overlay.className = "absolute inset-0 z-10 bg-transparent hidden";
    const spinner = document.createElement("div");
    spinner.className = "absolute right-4 top-4 w-4 h-4 border-2 border-gray-300 border-t-gray-700 rounded-full animate-spin";
    overlay.appendChild(spinner);
    this.containerTarget.appendChild(overlay);
  }
}
