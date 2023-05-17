// init
if (sessionStorage.getItem("internal") == null) {
    loadConfig()
} else {
    applyConfig()
}


// functions
async function loadConfig() {
    resCode = null
    resBody = await fetch("/config", {method: "GET"})
    .then((response) => {
        resCode = response.status
        return response.json()
    })
    .then((data) => data)
    
    if (resCode == 200) {
        var fields = Object.keys(resBody);
        fields.forEach(field => {
            sessionStorage.setItem(field, resBody[field])
        });
        applyConfig()
    } else {
        console.log("unexpected error while loading config");
    }
}

async function applyConfig() {
    if (sessionStorage.getItem("internal") === "false") {
        document.querySelector(".navbar-toggler").classList.add("visually-hidden")
        document.querySelector("#navbarsMain").classList.add("visually-hidden")
    }
}