// DOM elements
const uploadLink = document.querySelector("#datasets")
const datasetContainer = document.querySelector("#datasetContainer")


// init
uploadLink.classList.add("active")
loadDatasets()


// functions
function addDataSet(id, label, timeLeft, size, download_filename, downloads) {
    wrapper = document.createElement('div')
    wrapper.innerHTML = [
        '<div>',
        '   <div class="card my-3">',
        `   <div class="card-header">ID: ${id}</div>`,
        '       <div class="card-body">',
        `           <h5 class="card-title">${label}</h5>`,
        `           <p class="card-text">Retention time:\t ${timeLeft}<br>`,
        `           Total file size:\t ${size}<br>`,
        `           Downloads:\t ${downloads}</p>`,
        `           <a class="btn btn-primary" href="/datasets/${id}" download="${download_filename}">Download</a>`,
        '       </div>',
        '   </div>',
        '   </div>',
        '</div>'
    ].join('')
  
    datasetContainer.append(wrapper)
}

async function loadDatasets() {
    resCode = null
    resBody = await fetch("/datasets", {method: "GET"})
    .then((response) => {
        resCode = response.status
        return response.json()
    })
    .then((data) => data)
    
    if (resCode == 200) {
        if (resBody.length == 0) {
            datasetContainer.innerHTML = '<p>no Data Sets available</p>'
        } else {
            resBody.forEach(e => {
                addDataSet(e.id, e.label, e.time_left, e.size_total, e.download_filename, e.downloads)
            });
        }
    } else {
        // add error handling
    }
}