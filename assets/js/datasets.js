// DOM elements
const copyLinks = document.querySelectorAll(".copy-link")


//init 
if (!isSecureContext) {
    copyLinks.forEach(el => el.classList.add("visually-hidden"))
}