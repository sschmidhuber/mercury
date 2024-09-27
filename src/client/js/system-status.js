import {html, css} from '../client/deps/lit-core.min.js';
import {BootstrapElement} from '../client/deps/BootstrapElement.js';

class SystemStatus extends BootstrapElement {
  static properties = {
      _datasets: {state: true},
      _files: {state: true},
      _totalStorage: {state: true},
      _availableStorage: {state: true},
      _usedStorage: {state: true},
      _usedStorageRel: {state: true},
      _internal: {state: true}
  }

  constructor() {
      super();
      this.updateStatus()
  }

  async updateStatus() {
    var resCode = null
    var resBody = await fetch("/storage-status", {method: "GET"})
    .then((response) => {
        resCode = response.status
        return response.json()
    })
    .then((data) => data)
    
    if (resCode == 200) {
        this._datasets = resBody.count_ds
        this._files = resBody.count_files
        if (resBody.hasOwnProperty("total_storage")) {
          this._totalStorage = resBody.total_storage
          this._availableStorage = resBody.available_storage
          this._usedStorage = resBody.used_storage
          this._usedStorageRel = resBody.used_relative
          this._internal = true
        } else {
          this._internal = false
        }
    } else {
      console.log("failed to load system status");
    }
  }

  render() {
      return html`
      <span>
        <p style="display: inline-block; margin-right: 2em;" title="including hidden data sets">${this._datasets} ${this._datasets == 1 ? "Data Set" : "Data Sets"}</p>
        <p style="display: inline-block; margin-right: 2em;" title="including files of hidden data sets">${this._files} ${this._files == 1 ? "File" : "Files"}</p>
        <span ?hidden=${!this._internal}>
          <p  class="d-none d-lg-inline-block" style="margin-right: 2em;" title="Used storage includes not yet cleand up files.">Total Storage: ${this._totalStorage} (${this._usedStorageRel} used)</p>
          <p class="d-none d-xl-inline-block">Free Storage: ${this._availableStorage}</p>
        </span>
      </span>
      `
  }
}

customElements.define("system-status", SystemStatus)