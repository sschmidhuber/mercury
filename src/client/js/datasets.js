// DOM elements
const uploadLink = document.querySelector("#datasets")
const datasetContainer = document.querySelector("#datasetContainer")


// init
uploadLink.classList.add("active")
loadDatasets()


// functions
function addDataSet(id, label, timeLeft, size) {
    wrapper = document.createElement('div')
    wrapper.innerHTML = [
        '<div>',
        '   <div class="card my-3">',
        `   <div class="card-header">ID: ${id}</div>`,
        '       <div class="card-body">',
        `           <h5 class="card-title">${label}</h5>`,
        `           <p class="card-text">Retention time:\t <strong>${timeLeft}</strong>`,
        `           <p class="card-text">Total file size:\t <strong>${size}</strong></p>`,
        `           <a class="btn btn-primary" href="/datasets/${id}/status">Download</a>`,
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
        resBody.forEach(e => {
            addDataSet(e.id, e.label, e.time_left, e.size_total)
        });
    } else {
        // add error handling
    }
}