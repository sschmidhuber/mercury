// DOM elements
const uploadLink = document.querySelector("#upload")

const newUpload = document.querySelector("#newUpload")
const alertPlaceholder = document.querySelector("#alertPlaceholder")
const label = document.querySelector("#label")
const fileSelector = document.querySelector("#fileSelector")
const uploadButton = document.querySelector("#uploadButton")
 
const uploadStatus = document.querySelector("#uploadStatus")
const uploadDataset = document.querySelector("#uploadDataset")
const checkMalware = document.querySelector("#checkMalware")
const prepareDataset = document.querySelector("#prepareDataset")
const infoPanel = document.querySelector("#infoPanel")


// init
uploadLink.classList.add("active")

const alert = (message, type) => {
    const wrapper = document.createElement('div')
    wrapper.innerHTML = [
      `<div class="alert alert-${type} alert-dismissible" role="alert">`,
      `   <div>${message}</div>`,
      '   <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>',
      '</div>'
    ].join('')
  
    alertPlaceholder.append(wrapper)
  }  


// listeners
uploadButton.addEventListener("click", upload)

//functions
async function upload(event) {
    event.preventDefault()
    oldAlert = document.querySelector("#newUpload .alert")
    if (oldAlert != null) {
        oldAlert.remove()    
    }

    formData = new FormData()
    formData.append("label", label.value)
    
    files = fileSelector.files
    if (files.length == 0) {
        alert('Please select one or multiple files.', 'warning')
        return
    }
    for (let i = 0; i < files.length; i++) {
        filename = files[i].name
        formData.append(filename, files[i])        
    }
    newUpload.hidden = true
    let uploadStatusElement = document.createElement("upload-status");
    uploadStatusElement.setAttribute("state", "initial");
    uploadStatus.append(uploadStatusElement);
    uploadStatus.hidden = false
    resCode = null
    resBody = await fetch('/datasets', {method: "POST", body: formData})
    .then((response) => {
        resCode = response.status
        return response.json()
    })
    .then((data) => data)
    
    if (resCode == 201) {
        infoPanel.innerHTML = "<p>Upload successful, new Data Set ID: <b>" + resBody.id + "</b></p>"
        uploadStatusElement.setAttribute("state", "uploaded");
        uploadStatusElement.setAttribute("dataSetID", resBody.id);
    } else {
        uploadStatusElement.setAttribute("state", "failed");
        uploadStatusElement.setAttribute("error", resBody.detail)
    }
}