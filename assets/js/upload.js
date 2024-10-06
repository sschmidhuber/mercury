// DOM elements
const retentionTimeInput = document.querySelector("#retentionTimeInput");
const retentionTimeLabel = document.querySelector("#retentionTimeLabel");
const label = document.querySelector("#label")
const publicCheckbox = document.querySelector("#publicCheckbox")
const hiddenCheckbox = document.querySelector("#hiddenCheckbox")
const fileSelector = document.querySelector("#fileSelector")


const uploadLink = document.querySelector("#upload")

const newUpload = document.querySelector("#newUpload")
const alertPlaceholder = document.querySelector("#alertPlaceholder")

const retentionTime = document.querySelector("#retentionTime")
const directoryCheckbox = document.querySelector("#directoryCheckbox")
const fileSelectorLabel = document.querySelector("#fileSelectorLabel")
//const uploadButton = document.querySelector("#uploadButton")

const uploadStatus = document.querySelector("#uploadStatus")
const uploadDataset = document.querySelector("#uploadDataset")
const checkMalware = document.querySelector("#checkMalware")
const prepareDataset = document.querySelector("#prepareDataset")
const infoPanel = document.querySelector("#infoPanel")
const uploadProgressDataset = document.querySelector("#uploadProgressDataset")
const uploadFile = document.querySelector("#uploadFile")
const uploadProgressFile = document.querySelector("#uploadProgressFile")


// init
let wakeLock = null;


// listeners
document.addEventListener("visibilitychange", async () => {
    if (wakeLock !== null && document.visibilityState === "visible") {
        wakeLock = await navigator.wakeLock.request("screen");
    }
});

document.addEventListener("htmx:load", () => console.log("start upload"));


//uploadButton.addEventListener("click", upload);
directoryCheckbox.addEventListener("click", directoryMode);
publicCheckbox.addEventListener("click", publicVisibilityWarning);
hiddenCheckbox.addEventListener("click", publicVisibilityWarning);
fileSelector.addEventListener("input", publicVisibilityWarning);
fileSelector.addEventListener("input", resetNoFilesWarning);




//functions
function updateRetentionTime(rangeSelector) {
    let retentionTime = rangeSelector.value
    let labelText = `Retention time: ${retentionTime} h ${retentionTimeString(retentionTime)}`
    retentionTimeLabel.textContent = labelText
}


// return a given time in hours as string, e.g. 815 hours are 5 weeks
function retentionTimeString(hours) {
    if (hours <= 48) {
        return ""
    } else if (hours <= 504) {
        return "(~ " + Math.round(hours / 24) + " days)"
    } else {
        return "(~ " + Math.round(hours / 24 / 7) + " weeks)"
    }
}

// returns all selected files in an array, as required by the endpoint to create a dataset
function getFiles() {
    selectedFiles = []
    files = fileSelector.files    
    if (files.length !== 0) {
        // don't check for paths if webkitRelativePath is undefined (Fireforx for Android)
        if (files[0].webkitRelativePath == undefined) {
            // Firefox on Android
            for (let i = 0; i < files.length; i++) {
                selectedFiles.push({
                    path: files[i].name,
                    type: files[i].type,
                    size: files[i].size
                })
            }
        } else {
            // sane browsers
            for (let i = 0; i < files.length; i++) {
                selectedFiles.push({
                    path: files[i].webkitRelativePath == "" ? files[i].name : files[i].webkitRelativePath,
                    type: files[i].type,
                    size: files[i].size
                })
            }
        }
    }

    return selectedFiles
}


    /*
    // upload

    let dsid = resBody.id;
    let fid = 0;
    try {
        wakeLock = await navigator.wakeLock.request("screen");
        console.log("wakelock obtained");
    } catch (error) {
        console.log(`${error.name}, ${error.message}`);
    }

    //console.log(resBody.files[fid])

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

    if (wakeLock !== null) {
        wakeLock.release().then(() => {
            wakeLock = null;
        });
        console.log("wakeLock released")
    }
}
*/


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
        retention_time: retentionTimeInput.value,
        hidden: hiddenCheckbox.checked,
        public: publicCheckbox.checked,
        files: []
    }
    
    files = fileSelector.files
    if (files.length == 0) {
        alert('Please select one or multiple files.', 'warning', 'noFilesWarning')
        return
    }

    // TODO: This is dirty and needs to be done better
    // don't check for paths if webkitRelativePath is undefined (Fireforx for Android)
    if (files[0].webkitRelativePath == undefined) {
        // Firefox on Android
        for (let i = 0; i < files.length; i++) {
            reqBody.files.push({
                path: files[i].name,
                type: files[i].type,
                size: files[i].size
            })
        }
    } else {
        // sane browsers
        for (let i = 0; i < files.length; i++) {
            reqBody.files.push({
                path: files[i].webkitRelativePath == "" ? files[i].name : files[i].webkitRelativePath,
                type: files[i].type,
                size: files[i].size
            })
        }
    }
    
    newUpload.hidden = true
    uploadStatus.hidden = false
    //console.log(files);
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

    //console.log(resBody)

    let dsid = resBody.id;
    let fid = 0;
    try {
        wakeLock = await navigator.wakeLock.request("screen");
        console.log("wakelock obtained");
    } catch (error) {
        console.log(`${error.name}, ${error.message}`);
    }

    //console.log(resBody.files[fid])

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

    if (wakeLock !== null) {
        wakeLock.release().then(() => {
            wakeLock = null;
        });
        console.log("wakeLock released")
    }
}