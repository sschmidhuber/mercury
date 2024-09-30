import {html} from '../deps/lit-core.min.js';
import {BootstrapElement} from '../deps/BootstrapElement.js';

class DataSet extends BootstrapElement {
  static properties = {
      dataset: {type: Object}
  }

  constructor() {
      super();
  }

  emailBody() {
    let body = 'Download%20Link:%20' + this.dataset.download_url
    if (!this.dataset.public) {
      body += "%0A%0AThe data set is only available within the internal network."
    }
    body += "%0A%0A%0AMercury - the file exchange server"

    return body
  }

  copyLink(event) {
    event.preventDefault();
    navigator.clipboard.writeText(this.dataset.download_url);
    let img = this.renderRoot.querySelector("#clipboard-icon")
    console.log(img);
    img.src = "icons/check-circle.svg"
    setTimeout(() => {img.src = "icons/clipboard.svg"}, 3000)
  }

  render() {
    let emailBody = this.emailBody()
    let shareData = {
      url: this.dataset.download_url
    }
    let webShareAPI = !(navigator.canShare == undefined)
    if (webShareAPI) {
      webShareAPI = navigator.canShare()
    }

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
              <a class="btn btn-primary" href="/datasets/${this.dataset.id}" download="${this.dataset.download_filename}">
                <img src="icons/download.svg" style="padding-bottom: 0.2rem;"/>&nbsp;Download</a>
              <a ?hidden=${webShareAPI} class="btn btn-secondary" href="mailto:?to=&subject=${this.dataset.label}&body=${emailBody}">
                <span> <img src="icons/envelope.svg" style="padding-bottom: 0.2rem;"/> </span>
                <span class="d-none d-lg-inline-block">&nbsp;Send Link</span>
              </a>
              <a ?hidden=${!isSecureContext} @click=${this.copyLink} class="btn btn-secondary">
                <span> <img id="clipboard-icon" src="icons/clipboard.svg" style="padding-bottom: 0.2rem;"/> </span>
                <span class="d-none d-lg-inline-block">&nbsp;Copy Link</span>
              </a>
              <a ?hidden=${true} @click=${"navigator.share(shareData)"} class="btn btn-secondary">
                <!-- not implemented yet -->
                <span> <img src="icons/share-fill.svg" style="padding-bottom: 0.2rem;"/> </span>
                <span class="d-none d-lg-inline-block">&nbsp;Share Link</span>
              </a>
              <a ?hidden=${true} class="btn btn-secondary" href="">
                <!-- not implemented yet -->
                <span> <img src="icons/qr-code.svg" style="padding-bottom: 0.2rem;"/> </span>
                <span class="d-none d-lg-inline-block">&nbsp;QR Code</span>
              </a>
            </div>
          </div>
        </div>
      </div>
      `
  }
}

customElements.define("dataset-element", DataSet)