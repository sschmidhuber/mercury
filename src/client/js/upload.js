// DOM elements
const uploadLink = document.querySelector("#upload")

const newUpload = document.querySelector("#newUpload")
const alertPlaceholder = document.querySelector("#alertPlaceholder")
const label = document.querySelector("#label")
const retentionTime = document.querySelector("#retentionTime")
const publicCheckbox = document.querySelector("#publicCheckbox")
const hiddenCheckbox = document.querySelector("#hiddenCheckbox")
const directoryCheckbox = document.querySelector("#directoryCheckbox")
const fileSelectorLabel = document.querySelector("#fileSelectorLabel")
const fileSelector = document.querySelector("#fileSelector")
const uploadButton = document.querySelector("#uploadButton")
 
const uploadStatus = document.querySelector("#uploadStatus")
const uploadDataset = document.querySelector("#uploadDataset")
const checkMalware = document.querySelector("#checkMalware")
const prepareDataset = document.querySelector("#prepareDataset")
const infoPanel = document.querySelector("#infoPanel")


// init
uploadLink.classList.add("active")

const alert = (message, type, id) => {
    const wrapper = document.createElement('div')
    wrapper.innerHTML = [
      `<div id="${id}" class="alert alert-${type} alert-dismissible" role="alert">`,
      `   <div>${message}</div>`,
      '   <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>',
      '</div>'
    ].join('')
  
    alertPlaceholder.append(wrapper)
  }


// listeners
uploadButton.addEventListener("click", upload);
directoryCheckbox.addEventListener("click", directoryMode);
publicCheckbox.addEventListener("click", publicVisibilityWarning);
hiddenCheckbox.addEventListener("click", publicVisibilityWarning);
fileSelector.addEventListener("input", publicVisibilityWarning);
fileSelector.addEventListener("input", resetNoFilesWarning);
fileSelector.addEventListener("change", () => {console.log(fileSelector.files)});

//functions
function resetNoFilesWarning(event) {
    oldAlert = document.querySelector("#noFilesWarning")
    if (fileSelector.files.length != 0 && oldAlert != null) {
        oldAlert.remove()
    }
}

function publicVisibilityWarning(event) {
    oldAlert = document.querySelector("#publicVisibleWarning")
    if (oldAlert != null) {
        oldAlert.remove()    
    }
    if (publicCheckbox.checked && !hiddenCheckbox.checked && fileSelector.files.length != 0) {
        alert('This data set will be visible and accessible to anybody on the internet.', 'warning', 'publicVisibleWarning')
        return
    }
}

function directoryMode(event) {
    if (directoryCheckbox.checked == true) {
        fileSelectorLabel.textContent = "Choose a directory"
        fileSelector.setAttribute("webkitdirectory", "")
    } else {
        fileSelectorLabel.textContent = "Choose a file"
        fileSelector.removeAttribute("webkitdirectory")
    }
}

async function upload(event) {
    event.preventDefault()
    oldAlert = document.querySelector("#noFilesWarning")
    if (oldAlert != null) {
        oldAlert.remove()    
    }

    formData = new FormData()
    formData.append("label", label.value)
    formData.append("retention_time", retentionTime.retentionTime)
    formData.append("hidden", hiddenCheckbox.checked)
    formData.append("public", publicCheckbox.checked)
    
    files = fileSelector.files
    if (files.length == 0) {
        alert('Please select one or multiple files.', 'warning', 'noFilesWarning')
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
        if (resCode != 500) {
            return response.json()
        } else {
            null
        }
    })
    .then((data) => data)
    
    if (resCode == 201) {
        uploadStatusElement.setAttribute("state", "uploaded");
        uploadStatusElement.setAttribute("dataSetID", resBody.id);
        let datasetElement = document.createElement("dataset-element");
        datasetElement.setAttribute("dataset", JSON.stringify(resBody));
        uploadStatus.append(datasetElement)
    } else if (resCode == 500) {
        uploadStatusElement.setAttribute("state", "failed");
        uploadStatusElement.setAttribute("error", "Failed to process file upload.")       
    } else {
        uploadStatusElement.setAttribute("state", "failed");
        uploadStatusElement.setAttribute("error", resBody.detail)
    }
}