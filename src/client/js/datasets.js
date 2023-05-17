// DOM elements
const datasetLink = document.querySelector("#datasets")
const uploadLink = document.querySelector("#upload")
const datasetContainer = document.querySelector("#datasetContainer")


// init
datasetLink.classList.add("active")
loadDatasets()



// functions
function addDataSet(dataset) {
    let datasetElement = document.createElement("dataset-element");
    datasetElement.setAttribute("dataset", JSON.stringify(dataset));
    datasetContainer.append(datasetElement)
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
            datasetContainer.innerHTML = '<p>no visible Data Sets available</p>'
        } else {
            resBody.forEach(dataset => {
                addDataSet(dataset)
            });
        }
    } else {
        // add error handling
        console.log("unexpected error while loading datasets");
    }
}