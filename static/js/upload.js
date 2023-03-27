// DOM elements
uploadLink = document.querySelector("#upload")
uploadLink.classList.add("active")

newUpload = document.querySelector("#newUpload")
label = document.querySelector("#label")
fileSelector = document.querySelector("#fileSelector")
uploadButton = document.querySelector("#uploadButton")

uploadStatus = document.querySelector("#uploadStatus")
spinner = document.querySelector("#spinner")
infoPanel = document.querySelector("#infoPanel")


// listeners
uploadButton.addEventListener("click", uploadDataSet)


//functions
async function uploadDataSet(event) {
    event.preventDefault()
    //TODO: validate form input

    formData = new FormData()
    formData.append("label", label.value)
    files = fileSelector.files
    for (let i = 0; i < files.length; i++) {
        filename = files[i].name
        formData.append(filename, files[i])        
    }
    newUpload.hidden = true
    uploadStatus.hidden = false
    res = await fetch('/dataset', {method: "POST", body: formData})
    .then((response) => response.json())
    .then((data) => data)
    spinner.hidden = true
    infoPanel.textContent = "Data Set: " + res.id + " uploaded!"
}