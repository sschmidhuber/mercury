import {html, css} from '../deps/lit-core.min.js';
import {BootstrapElement} from '../deps/BootstrapElement.js';

class RetentionTimeSelector extends BootstrapElement {
  static properties = {
    default: {},
    retentionTime: {state: true},
    _retentionTimeFormated: {state: true}
  }

  static styles = [
    super.styles,
    css`
    .form-range::-moz-range-track {
      background-color: lightgray;
    }
    .form-range::-webkit-range-track {
      background-color: lightgrey;
    }
    .form-range::-ms-range-track {
      background-color: lightgrey;
    }
    `
  ]

  connectedCallback() {
    super.connectedCallback()
      this._retentionTimeFormated = "";
      this.retentionTime = this.default
  }

  // return a given time in hours as string, e.g. 815 hours are 5 weeks
  retentionTimeString(hours) {
    if (hours <= 48) {
      return ""
    } else if (hours <= 504) {
      return "(~ " + Math.round(hours / 24) + " days)"
    } else {
      return "(~ " + Math.round(hours / 24 / 7) + " weeks)"
    }
  }

  _change(e) {
    this.retentionTime = e.target.value
    this._retentionTimeFormated = this.retentionTimeString(e.target.value)
  }

  render() {
      return html`
      <label for="retentionTime" class="form-label">Retention time: ${this.retentionTime} h ${this._retentionTimeFormated}</label>
      <input @input=${this._change} type="range" class="form-range" min="1" step="1" max="720" id="retentionTime" value=48>
      `
  }
}

customElements.define("retention-time-selector", RetentionTimeSelector)