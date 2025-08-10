import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="bulk-select-drawer"
export default class extends Controller {
  connect() {
    // No-op; header text is already updated by bulk-select
  }
}
