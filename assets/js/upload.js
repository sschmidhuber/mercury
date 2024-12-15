// DOM elements
const retentionTimeInput = document.querySelector("#retentionTimeInput");
const retentionTimeLabel = document.querySelector("#retentionTimeLabel");
const label = document.querySelector("#label");
const publicCheckbox = document.querySelector("#publicCheckbox");
const hiddenCheckbox = document.querySelector("#hiddenCheckbox");
const directoryCheckbox = document.querySelector("#directoryCheckbox");
const fileSelector = document.querySelector("#fileSelector");


// init
let wakeLock = null;
let files = null;


// listeners
directoryCheckbox.addEventListener("change", directoryMode)
document.addEventListener("visibilitychange", async () => {
    if (wakeLock !== null && document.visibilityState === "visible") {
        wakeLock = await navigator.wakeLock.request("screen");
    }
});
document.body.addEventListener("uploadCompleted", releaseWakelock);


//functions
function updateRetentionTime(rangeSelector) {
    let retentionTime = rangeSelector.value
    let labelText = `Retention time: ${retentionTime} h ${retentionTimeString(retentionTime)}`
    retentionTimeLabel.textContent = labelText
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
    let selectedFiles = []
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

    // obtain wakeLock
    try {
        wakeLock = navigator.wakeLock.request("screen");
        console.log("wakelock obtained");
    } catch (error) {
        console.log(`${error.name}, ${error.message}`);
    }

    return selectedFiles
}


// return a specified data chunk from one of the files selected for upload
function getNextChunk(event) {
    if (files === null || files.length === 0) {
        console.log("no files selected");
        return null;
    } else if (files.length < event.detail.fid) {
        console.log("less files available than expected");
        return null;        
    } else {
        file = files[event.detail.fid - 1]
        if (event.detail.chunk === 1 && file.size <= sessionStorage.chunk_size) {
            // return complete file in one chunk
            return file
        } else {
            // slice data chunk from file
            start = (event.detail.chunk - 1) * sessionStorage.chunk_size;
            end = event.detail.chunk * sessionStorage.chunk_size > file.size ? file.size : event.detail.chunk * sessionStorage.chunk_size;
            return file.slice(start, end);
        }        
    }
}


async function releaseWakelock() {
    if (wakeLock !== null) {
        wl = await wakeLock
        wl.release().then(() => {
            wakeLock = null;
        });
        console.log("wakeLock released");
    }
}