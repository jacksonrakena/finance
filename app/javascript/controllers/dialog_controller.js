import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="DS--dialog"
// Adds enter/exit animations for modal and drawer variants.
export default class extends Controller {
  static values = {
    autoOpen: { type: Boolean, default: true },
    reloadOnClose: { type: Boolean, default: false },
  };

  connect() {
    // Find outer/inner containers
    this.outer = this.element.querySelector("[data-dialog-outer]");
    this.inner = this.element.querySelector("[data-dialog-inner]");

    if (!this.outer || !this.inner) return;

    // Prepare initial state for animation
    this.outer.classList.add("opacity-0");
    this.inner.classList.add("translate-x-4", "opacity-0");

    // Open animation on next tick
    requestAnimationFrame(() => {
      this.outer.classList.add("transition", "duration-200");
      this.inner.classList.add("transition", "duration-200");

      this.outer.classList.remove("opacity-0");
      this.inner.classList.remove("translate-x-4", "opacity-0");
    });
  }

  close(event) {
    event?.preventDefault();

    if (!this.outer || !this.inner) return;

    // Exit animation
    this.outer.classList.add("opacity-0");
    this.inner.classList.add("translate-x-4", "opacity-0");

    setTimeout(() => {
      // If using Turbo Frames, navigate back/clear frame
      if (this.reloadOnCloseValue) {
        window.location.reload();
      } else {
        // Fallback: remove the frame content
        this.element.remove();
      }
    }, 180);
  }

  clickOutside(event) {
    if (event.target === this.element) {
      this.close(event);
    }
  }
}
