import {LitElement, html} from 'https://cdn.jsdelivr.net/gh/lit/dist@2/core/lit-core.min.js';

class UploadStatus extends LitElement {
  static properties = {
      state: {},
      dataSetID: {},
      _message: {state: true},
      _alertType: {state: true},
      _in_progress: {state: true},
      _dsStage: {},
      _updateIntervalID: {}
  }

  constructor() {
      super();
      this._in_progress = true
      this._message = "Upload data to server ..."
      this._alertType = "alert-primary"
      this._dsStage = null
      this._updateIntervalID = null
  }

  async updateStatus(id) {
    resCode = null
    resBody = await fetch("/datasets/" + id + "/status", {method: "GET"})
    .then((response) => {
        resCode = response.status
        return response.json()
    })
    .then((data) => data)

    console.log(resBody.stage);
    
    if (resCode == 200) {
        if (resBody.stage != this._dsStage) {
            switch (resBody.stage) {
                case "scanned":
                    this._message = "Prepare data set for download ..."
                    break;
                case "available":
                    this._message = "New data set successfully created"
                    this._alertType = "alert-success"
                    this._in_progress = false
                    clearInterval(this._updateIntervalID)
                    // show link and DataSet preview
                    break;
                case "deleted":
                  if (this._dsStage == "initial") {
                    this._message = "Malware detected! The data set was deleted"
                    this._alertType = "alert-danger"
                    this._in_progress = false
                  } else {
                    this._message = "Something went wrong, the data set was deleted"
                    this._alertType = "alert-danger"
                    this._in_progress = false
                  }
                  clearInterval(this._updateIntervalID)
                  break;
                default:
                  this._alertType = "alert-danger"
                  this._message = "Something went wrong, unknown state"
                  this._in_progress = false
                  clearInterval(this._updateIntervalID)
                  break;
            }
            this._dsStage = resBody.stage
        }
    } else {
      this._alertType = "alert-danger"
      this._in_progress = false
      this._message = "Upload failed: " + resBody.error
      clearInterval(this._updateIntervalID)
    }
  }


  willUpdate() {
    if (this.state == "uploaded" && this._dsStage == null) {
      this._message = "Check data for malware ..."
      this._dsStage = "initial"
      this._updateIntervalID = setInterval(() => {
          this.updateStatus(this.dataSetID)
      }, 1000);
    }
  }

  createRenderRoot() {
    return this;
  }

  render() {
      return html`
        <div class="alert ${this._alertType}" role="alert">
          <div class="d-flex align-items-center">
            ${this._message}
            <div aria-hidden="true" class="spinner-border ms-auto" role="status" ?hidden=${!this._in_progress}></div>
          </div>
        </div>
      `
  }
}

customElements.define("upload-status", UploadStatus)