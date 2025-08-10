import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="bulk-edit"
// Submits a GET to open the drawer, then POSTs per entry to update, showing progress
export default class extends Controller {
  static targets = ["form"];
  static values = {
    entryIds: Array,
  };
}
