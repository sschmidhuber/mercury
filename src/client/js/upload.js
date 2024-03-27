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
const uploadProgressDataset = document.querySelector("#uploadProgressDataset")
const uploadFile = document.querySelector("#uploadFile")
const uploadProgressFile = document.querySelector("#uploadProgressFile")


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
let wakeLock = null;


// listeners
uploadButton.addEventListener("click", upload);
directoryCheckbox.addEventListener("click", directoryMode);
publicCheckbox.addEventListener("click", publicVisibilityWarning);
hiddenCheckbox.addEventListener("click", publicVisibilityWarning);
fileSelector.addEventListener("input", publicVisibilityWarning);
fileSelector.addEventListener("input", resetNoFilesWarning);

document.addEventListener("visibilitychange", async () => {
    if (wakeLock !== null && document.visibilityState === "visible") {
      wakeLock = await navigator.wakeLock.request("screen");
    }
  });

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

function updateProgress(progressDataset, progressFile, filename) {
    uploadProgressDataset.textContent = progressDataset;
    uploadFile.textContent = filename;
    uploadProgressFile.textContent = progressFile;
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

    let reqBody = {
        label: label.value,
        retention_time: retentionTime.retentionTime,
        hidden: hiddenCheckbox.checked,
        public: publicCheckbox.checked,
        files: []
    }
    
    files = fileSelector.files
    if (files.length == 0) {
        alert('Please select one or multiple files.', 'warning', 'noFilesWarning')
        return
    }
    for (let i = 0; i < files.length; i++) {
        reqBody.files.push({
            path: files[i].webkitRelativePath == "" ? files[i].name : files[i].webkitRelativePath,
            type: files[i].type,
            size: files[i].size
        })
    }
    newUpload.hidden = true
    uploadStatus.hidden = false
    console.log(files);
    resCode = null
    resBody = await fetch('/datasets', {method: "POST", body: JSON.stringify(reqBody)})
    .then((response) => {
        resCode = response.status
        if (resCode != 500) {
            return response.json()
        } else {
            null
        }
    })
    .then((data) => data)

    let dsid = resBody.id;
    let fid = 0;
    wakeLock = await navigator.wakeLock.request("screen");

    for (const file of files) {
        let chunks_received = resBody.files[fid].chunks_received;
        let chunks_expected = resBody.files[fid].chunks_total;
        
        // upload file chunks
        if (file.size <= sessionStorage.chunk_size) {
            formData = new FormData()
            formData.append(file.name, file)
            responseCode = null
            responseBody = await fetch(`/datasets/${dsid}/files/${fid + 1}/1`, { method: "PUT", body: formData })
                .then((response) => {
                    responseCode = response.status
                    if (responseCode != 500) {
                        return response.json()
                    }
                })
                .then((data) => data);
                updateProgress(responseBody.progress_dataset, responseBody.progress_file, responseBody.file);
        } else if (file.size > sessionStorage.chunk_size) {
            for (let chunk = 1; chunk <= chunks_expected; chunk++) {
                start = (chunk - 1) * sessionStorage.chunk_size;
                end = chunk * sessionStorage.chunk_size > file.size ? file.size : chunk * sessionStorage.chunk_size
                formData = new FormData();
                formData.append(file.name, file.slice(start, end))
                responseCode = null
                responseBody = await fetch(`/datasets/${dsid}/files/${fid + 1}/${chunk}`, { method: "PUT", body: formData })
                .then((response) => {
                    responseCode = response.status
                    if (responseCode != 500) {
                        return response.json()
                    }
                })
                .then((data) => data);
                updateProgress(responseBody.progress_dataset, responseBody.progress_file, responseBody.file);
            }
        }

        fid++;
    }

    wakeLock.release().then(() => {
        wakeLock = null;
      });
}