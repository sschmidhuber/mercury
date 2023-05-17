import {html} from '../deps/lit-core.min.js';
import {BootstrapElement} from '../deps/BootstrapElement.js';

class DataSet extends BootstrapElement {
  static properties = {
      dataset: {type: Object}
  }

  constructor() {
      super();
  }


  render() {
    console.log(this.dataset);
      return html`
      <div>
        <div class="shadow card my-3">
          <div class="card-header">
            <span class="d-lg-none" style="margin-right: 0.5em;" title="ID: ${this.dataset.id}">ID: ${this.dataset.id.slice(0,8)}...</span>
            <span class="d-none d-lg-inline-block" style="margin-right: 0.5em;">ID: ${this.dataset.id}</span>
            <span class="badge rounded-pill bg-secondary">${this.dataset.public ? "Public" : ""}</span>
            <span class="badge rounded-pill bg-secondary">${this.dataset.hidden ? "Hidden" : ""}</span>
          </div>
          <div class="card-body">
            <h5 class="card-title">${this.dataset.label}</h5><p class="card-text">Retention time: ${this.dataset.time_left_f}<br>
              Size: ${this.dataset.size_total_f} (${this.dataset.files.length} ${this.dataset.files.length == 1 ? "file" : "files"})<br>
              Downloads: ${this.dataset.downloads}</p>
              <a class="btn btn-primary btn-sm" href="/datasets/${this.dataset.id}" download="${this.dataset.download_filename}">Download</a>
            </div>
          </div>
        </div>
      </div>
      `
  }
}

customElements.define("dataset-element", DataSet)