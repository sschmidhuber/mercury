// DOM elements
const uploadLink = document.querySelector("#upload")

const newUpload = document.querySelector("#newUpload")
const alertPlaceholder = document.querySelector("#alertPlaceholder")
const label = document.querySelector("#label")
const fileSelector = document.querySelector("#fileSelector")
const uploadButton = document.querySelector("#uploadButton")
 
const uploadStatus = document.querySelector("#uploadStatus")
const spinner = document.querySelector("#spinner")
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
uploadButton.addEventListener("click", uploadDataSet)


//functions
async function uploadDataSet(event) {
    event.preventDefault()
    oldAlert = document.querySelector(".alert")
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
    uploadStatus.hidden = false
    res = await fetch('/datasets', {method: "POST", body: formData})
    .then((response) => response.json())
    .then((data) => data)
    spinner.hidden = true
    infoPanel.textContent = "Data Set: " + res.id + " uploaded!"
}