using HTTP

@info "download file"
res = HTTP.request("GET", "http://127.0.0.1:8080/oxygen")

@info "close session"
sleep(1)

exit(0)